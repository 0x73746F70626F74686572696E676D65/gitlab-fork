# frozen_string_literal: true

module DependencyManagement
  # rubocop:disable CodeReuse/ActiveRecord -- Code won't be reused outside this context
  class AggregationsFinder
    include Gitlab::Utils::StrongMemoize

    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 20
    DEFAULT_SORT_COLUMNS = %i[component_id component_version_id].freeze
    SUPPORTED_SORT_COLUMNS = %i[component_name highest_severity package_manager licenses].freeze

    def initialize(namespace, params: {})
      @namespace = namespace
      @params = params
    end

    def execute
      group_columns = distinct_columns.map { |column| column_expression(column, 'outer_occurrences') }

      # JSONB_AGG also aggregates nulls, which we want to avoid.
      # The FILTER statement prevents nulls from being concatenated into the array,
      # and the COALESCE function gives us an empty array instead of NULL when there are no items.
      licenses_select = <<~SQL
        COALESCE(
          JSONB_AGG(outer_occurrences.licenses->0) FILTER (WHERE outer_occurrences.licenses->0 IS NOT NULL),
        '[]') AS licenses
      SQL

      Sbom::Occurrence.with(namespaces_cte.to_arel)
        .select(
          *group_columns,
          'MIN(outer_occurrences.id)::bigint AS id',
          'MIN(outer_occurrences.package_manager) AS package_manager',
          'MIN(outer_occurrences.input_file_path) AS input_file_path',
          licenses_select,
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

    def keyset_order(column_expression_evaluator:, order_expression_evaluator:)
      order_definitions = orderings.map do |column, direction|
        column_expression = column_expression_evaluator.call(column)
        order_expression = order_expression_evaluator.call(column)

        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: column.to_s,
          column_expression: column_expression,
          order_expression: direction == :desc ? order_expression.desc : order_expression.asc,
          nullable: nullable(column, direction),
          order_direction: direction
        )
      end

      Gitlab::Pagination::Keyset::Order.build(order_definitions)
    end

    def outer_order
      keyset_order(
        column_expression_evaluator: ->(column) { column_expression(column, 'outer_occurrences') },
        order_expression_evaluator: ->(column) { sql_min(column, 'outer_occurrences') }
      )
    end

    def namespaces_cte
      ::Gitlab::SQL::CTE.new(:namespaces, namespace.self_and_descendants.select(:traversal_ids))
    end

    def inner_occurrences
      relation = Sbom::Occurrence
        .where('sbom_occurrences.traversal_ids = namespaces.traversal_ids::bigint[]')
        .unarchived

      relation = filter_by_licences(relation)

      relation
        .order(inner_order)
        .select(distinct(on: distinct_columns))
        .keyset_paginate(cursor: cursor, per_page: page_size)
    end

    def filter_by_licences(relation)
      return relation unless params[:licenses].present?

      relation.by_primary_license(params[:licenses])
    end

    def inner_order
      evaluator = ->(column) { column_expression(column) }

      keyset_order(
        column_expression_evaluator: evaluator,
        order_expression_evaluator: evaluator
      )
    end

    def outer_occurrences
      order = orderings.map do |column, direction|
        column_expression = column_expression(column, 'inner_occurrences')
        direction == :desc ? column_expression.desc : column_expression.asc
      end

      Sbom::Occurrence.select(distinct(on: distinct_columns, table_name: 'inner_occurrences'))
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

    def distinct_columns
      orderings.keys
    end

    def column_expression(column, table_name = 'sbom_occurrences')
      if column == :licenses
        Sbom::Occurrence.connection.quote_table_name(table_name)
          .then { |table_name| Arel.sql("(#{table_name}.\"licenses\" -> 0 ->> 'spdx_identifier')::text") }
      else
        Sbom::Occurrence.arel_table.alias(table_name)[column]
      end
    end

    def distinct(on:, table_name: 'sbom_occurrences')
      select_values = Sbom::Occurrence.column_names.map do |column|
        Sbom::Occurrence.connection.quote_table_name("#{table_name}.#{column}")
      end
      distinct_values = on.map { |column| column_expression(column, table_name) }

      distinct_sql = Arel::Nodes::DistinctOn.new(distinct_values).to_sql

      "#{distinct_sql} #{select_values.join(', ')}"
    end

    def sql_min(column, table_name = 'sbom_occurrences')
      Arel::Nodes::NamedFunction.new('MIN', [column_expression(column, table_name)])
    end

    def nullable(column_name, direction)
      column = Sbom::Occurrence.columns_hash[column_name.to_s]

      return :not_nullable unless column.null

      # The default behavior for postgres is to have nulls first
      # when in descending order, and nulls last otherwise.
      direction == :desc ? :nulls_first : :nulls_last
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
