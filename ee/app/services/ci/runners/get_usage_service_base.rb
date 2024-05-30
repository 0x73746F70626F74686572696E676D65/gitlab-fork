# frozen_string_literal: true

module Ci
  module Runners
    class GetUsageServiceBase
      include Gitlab::Utils::StrongMemoize

      def initialize(current_user, runner_type:, from_date:, to_date:, max_item_count:, additional_group_by_columns: [])
        @current_user = current_user
        @runner_type = Ci::Runner.runner_types[runner_type]
        @from_date = from_date
        @to_date = to_date
        @max_item_count = max_item_count
        @additional_group_by_columns = additional_group_by_columns
      end

      def execute
        unless ::Gitlab::ClickHouse.configured?
          return ServiceResponse.error(message: 'ClickHouse database is not configured',
            reason: :db_not_configured)
        end

        unless Ability.allowed?(@current_user, :read_runner_usage)
          return ServiceResponse.error(message: 'Insufficient permissions',
            reason: :insufficient_permissions)
        end

        data = ClickHouse::Client.select(clickhouse_query, :main)
        ServiceResponse.success(payload: data)
      end

      private

      attr_reader :runner_type, :from_date, :to_date, :max_item_count, :additional_group_by_columns

      def clickhouse_query
        grouping_columns = ["#{bucket_column}_bucket", *additional_group_by_columns].join(', ')
        raw_query = <<~SQL.squish
          WITH top_buckets AS
            (
              SELECT #{bucket_column} AS #{bucket_column}_bucket
              FROM #{table_name}
              WHERE #{where_conditions}
              GROUP BY #{bucket_column}
              ORDER BY sumSimpleState(total_duration) DESC
              LIMIT {max_item_count: UInt64}
            )
          SELECT
            IF(#{table_name}.#{bucket_column} IN top_buckets, #{table_name}.#{bucket_column}, NULL)
              AS #{bucket_column}_bucket,
            #{select_list}
          FROM #{table_name}
          WHERE #{where_conditions}
          GROUP BY #{grouping_columns}
          ORDER BY #{order_list}
        SQL

        ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
      end

      def table_name
        raise NotImplementedError
      end

      def bucket_column
        raise NotImplementedError
      end

      def select_list
        [
          *additional_group_by_columns,
          'countMerge(count_builds) AS count_builds',
          'toUInt64(sumSimpleState(total_duration) / 60000) AS total_duration_in_mins'
        ].join(', ')
      end
      strong_memoize_attr :select_list

      def order_list
        [
          "(#{bucket_column}_bucket IS NULL)",
          'total_duration_in_mins DESC',
          "#{bucket_column}_bucket ASC"
        ].join(', ')
      end
      strong_memoize_attr :order_list

      def where_conditions
        <<~SQL
          #{'runner_type = {runner_type: UInt8} AND' if runner_type}
          finished_at_bucket >= {from_date: DateTime('UTC', 6)} AND
          finished_at_bucket < {to_date: DateTime('UTC', 6)}
        SQL
      end
      strong_memoize_attr :where_conditions

      def placeholders
        {
          runner_type: runner_type,
          from_date: format_date(from_date),
          to_date: format_date(to_date + 1), # Include jobs until the end of the day
          max_item_count: max_item_count
        }.compact
      end

      def format_date(date)
        date.strftime('%Y-%m-%d %H:%M:%S')
      end
    end
  end
end
