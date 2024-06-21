# frozen_string_literal: true

module DependencyManagement
  # rubocop:disable CodeReuse/ActiveRecord -- Code won't be reused outside this context
  class AggregationsFinder
    include Gitlab::Utils::StrongMemoize

    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 20
    DEFAULT_SORT_COLUMNS = %i[component_id component_version_id].freeze
    SUPPORTED_SORT_COLUMNS = %i[component_name highest_severity package_manager].freeze

    def initialize(namespace, params: {})
      @namespace = namespace
      @params = params
    end

    def execute
      group_columns = distinct_columns.map { |column| "outer_occurrences.#{column}" }

      Sbom::Occurrence.with(namespaces_cte.to_arel)
        .select(
          *group_columns,
          'MIN(outer_occurrences.id)::bigint AS id',
          'MIN(outer_occurrences.package_manager) AS package_manager',
          'MIN(outer_occurrences.input_file_path) AS input_file_path',
          'JSONB_AGG(outer_occurrences.licenses->0) AS licenses',
          'SUM(counts.occurrence_count)::integer AS occurrence_count',
          'SUM(counts.vulnerability_count)::integer AS vulnerability_count',
          'SUM(counts.project_count)::integer AS project_count'
        )
        .from("(#{outer_occurrences.to_sql}) outer_occurrences, LATERAL (#{counts.to_sql}) counts")
        .group(*group_columns)
        .order(outer_order)
    end

    private

    attr_reader :namespace, :params

    def distinct_columns
      orderings.keys
    end

    def keyset_order(column_expression_evaluator:, order_expression_evaluator:)
      order_definitions = orderings.map do |column, direction|
        column_expression = column_expression_evaluator.call(column)
        order_expression = order_expression_evaluator.call(column)

        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: column.to_s,
          column_expression: column_expression,
          order_expression: direction == :desc ? order_expression.desc : order_expression.asc,
          nullable: :not_nullable,
          order_direction: direction
        )
      end

      Gitlab::Pagination::Keyset::Order.build(order_definitions)
    end

    def outer_order
      keyset_order(
        column_expression_evaluator: ->(column) { Sbom::Occurrence.arel_table.alias('outer_occurrences')[column] },
        order_expression_evaluator: ->(column) { Arel.sql("MIN(outer_occurrences.#{column})") }
      )
    end

    def namespaces_cte
      ::Gitlab::SQL::CTE.new(:namespaces, namespace.self_and_descendants.select(:traversal_ids))
    end

    def inner_occurrences
      Sbom::Occurrence.where('sbom_occurrences.traversal_ids = namespaces.traversal_ids::bigint[]')
        .unarchived
        .order(inner_order)
        .select_distinct(on: distinct_columns)
        .keyset_paginate(cursor: cursor, per_page: page_size)
    end

    def inner_order
      evaluator = ->(column) { Sbom::Occurrence.arel_table[column] }
      keyset_order(
        column_expression_evaluator: evaluator,
        order_expression_evaluator: evaluator
      )
    end

    def outer_occurrences
      order = orderings.map do |column, direction|
        "inner_occurrences.#{column} #{direction.to_s.upcase}"
      end

      Sbom::Occurrence.select_distinct(on: distinct_columns, table_name: '"inner_occurrences"')
      .from("namespaces, LATERAL (#{inner_occurrences.to_sql}) inner_occurrences")
      .order(*order)
      .limit(page_size + 1)
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
      [params.fetch(:per_page, DEFAULT_PAGE_SIZE).to_i, MAX_PAGE_SIZE].min
    end

    def cursor
      params[:cursor]
    end

    def orderings
      default_orderings = DEFAULT_SORT_COLUMNS.index_with { sort_direction }

      return default_orderings unless sort_by.present?

      # The `sort_by` column must come first in the `ORDER BY` statement.
      # Create a new hash to ensure that it is in the front when enumerating.
      Hash[sort_by => sort_direction, **default_orderings]
    end
    strong_memoize_attr :orderings

    def sort_by
      sort_by = params[:sort_by]

      return unless sort_by && SUPPORTED_SORT_COLUMNS.include?(sort_by)

      sort_by
    end
    strong_memoize_attr :sort_by

    def sort_direction
      params[:sort]&.downcase&.to_sym == :desc ? :desc : :asc
    end
  end
  # rubocop:enable CodeReuse/ActiveRecord
end
