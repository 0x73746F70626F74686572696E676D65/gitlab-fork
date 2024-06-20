# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class CodeSuggestionUsageRateService
      QUERY = <<~SQL
        -- cte to load code contributors
        WITH code_contributors AS (
          SELECT DISTINCT author_id
          FROM contributions
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
          AND "contributions"."action" = 5
        )
        SELECT
          COALESCE((SELECT count(*) FROM code_contributors), 0) as code_contributors_count,
          COALESCE((
            SELECT COUNT(DISTINCT user_id)
            FROM code_suggestion_daily_usages
            WHERE user_id IN (SELECT author_id FROM code_contributors)
            AND timestamp >= {from:Date}
            AND timestamp <= {to:Date}
          ), 0) as code_contributors_with_ai
      SQL
      private_constant :QUERY

      def initialize(current_user, namespace:, from:, to:)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
      end

      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)

        data = usage_data

        ServiceResponse.success(payload: {
          code_contributors_count: data['code_contributors_count'],
          code_suggestions_contributors_count: data['code_contributors_with_ai']
        })
      end

      private

      attr_reader :current_user, :namespace, :from, :to

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end

      def usage_data
        query = ClickHouse::Client::Query.new(raw_query: QUERY, placeholders: placeholders)
        ClickHouse::Client.select(query, :main).first
      end

      def placeholders
        {
          traversal_path: "#{namespace.traversal_ids.join('/')}/",
          from: from.strftime('%Y-%m-%d'),
          to: to.strftime('%Y-%m-%d')
        }
      end
    end
  end
end
