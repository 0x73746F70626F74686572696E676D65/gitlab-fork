# frozen_string_literal: true

module DependencyManagement
  # rubocop:disable CodeReuse/ActiveRecord -- Code won't be reused outside this context
  class AggregationsFinder
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 20
    DISTINCT_BY = %i[component_id component_version_id].freeze

    def initialize(namespace, params: {})
      @namespace = namespace
      @params = params
    end

    def execute
      Sbom::Occurrence.with(namespaces_cte.to_arel)
        .select(
          'MIN(outer_occurrences.id)::bigint AS id',
          'outer_occurrences.component_id',
          'outer_occurrences.component_version_id',
          'MIN(outer_occurrences.package_manager) AS package_manager',
          'MIN(outer_occurrences.input_file_path) AS input_file_path',
          'JSONB_AGG(outer_occurrences.licenses->0) AS licenses',
          'SUM(counts.occurrence_count)::integer AS occurrence_count',
          'SUM(counts.vulnerability_count)::integer AS vulnerability_count',
          'SUM(counts.project_count)::integer AS project_count'
        )
        .from("(#{outer_occurrences.to_sql}) outer_occurrences, LATERAL (#{counts.to_sql}) counts")
        .group('outer_occurrences.component_id', 'outer_occurrences.component_version_id')
        .order('MIN(outer_occurrences.component_id) ASC', 'MIN(outer_occurrences.component_version_id) ASC')
    end

    private

    attr_reader :namespace, :params

    def namespaces_cte
      ::Gitlab::SQL::CTE.new(:namespaces, namespace.self_and_descendants.select(:traversal_ids))
    end

    def inner_occurrences
      Sbom::Occurrence.where('sbom_occurrences.traversal_ids = namespaces.traversal_ids::bigint[]')
        .unarchived
        .order(*DISTINCT_BY)
        .limit(page_size)
        .select_distinct(on: DISTINCT_BY)
    end

    def outer_occurrences
      Sbom::Occurrence.select_distinct(on: DISTINCT_BY, table_name: '"inner_occurrences"')
      .from("namespaces, LATERAL (#{inner_occurrences.to_sql}) inner_occurrences")
      .order('inner_occurrences.component_id ASC', 'inner_occurrences.component_version_id ASC')
      .limit(page_size)
    end

    def counts
      Sbom::Occurrence.select('COUNT(project_id) AS occurrence_count')
        .select('COUNT(DISTINCT project_id) project_count')
        .select('SUM(vulnerability_count) vulnerability_count')
        .for_namespace_and_descendants(namespace)
        .unarchived
        .where('sbom_occurrences.component_version_id = outer_occurrences.component_version_id')
    end

    def page_size
      [params.fetch(:per_page, DEFAULT_PAGE_SIZE), MAX_PAGE_SIZE].min
    end
  end
  # rubocop:enable CodeReuse/ActiveRecord
end
