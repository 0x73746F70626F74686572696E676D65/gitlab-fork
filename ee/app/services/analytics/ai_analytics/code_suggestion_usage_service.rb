# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class CodeSuggestionUsageService
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
        SELECT %{fields}
      SQL
      private_constant :QUERY

      CODE_CONTRIBUTORS_COUNT_QUERY = "SELECT count(*) FROM code_contributors"
      private_constant :CODE_CONTRIBUTORS_COUNT_QUERY

      CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY = <<~SQL
        SELECT COUNT(DISTINCT user_id)
          FROM code_suggestion_daily_usages
          WHERE user_id IN (SELECT author_id FROM code_contributors)
          AND timestamp >= {from:Date}
          AND timestamp <= {to:Date}
      SQL
      private_constant :CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY

      CODE_SUGGESTIONS_SHOWN_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_daily_events
        WHERE user_id IN (SELECT author_id FROM code_contributors)
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::CodeSuggestionsUsage::EVENTS['code_suggestion_shown_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_SHOWN_COUNT_QUERY

      CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY = <<~SQL.freeze
        SELECT SUM(occurrences)
        FROM code_suggestion_daily_events
        WHERE user_id IN (SELECT author_id FROM code_contributors)
        AND date >= {from:Date}
        AND date <= {to:Date}
        AND event = #{::Ai::CodeSuggestionsUsage::EVENTS['code_suggestion_accepted_in_ide']}
      SQL
      private_constant :CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY

      FIELDS_SUBQUERIES = {
        code_contributors_count: CODE_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_contributors_count: CODE_SUGGESTIONS_CONTRIBUTORS_COUNT_QUERY,
        code_suggestions_shown_count: CODE_SUGGESTIONS_SHOWN_COUNT_QUERY,
        code_suggestions_accepted_count: CODE_SUGGESTIONS_ACCEPTED_COUNT_QUERY

      }.freeze
      private_constant :FIELDS_SUBQUERIES

      FIELDS = FIELDS_SUBQUERIES.keys

      def initialize(current_user, namespace:, from:, to:, fields: FIELDS)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
        @fields = fields
      end

      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)

        ServiceResponse.success(payload: usage_data.symbolize_keys!)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :fields

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end

      def usage_data
        query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
        ClickHouse::Client.select(query, :main).first
      end

      def raw_query
        raw_fields = fields.map do |field|
          "(#{FIELDS_SUBQUERIES[field]}) as #{field}"
        end.join(',')

        format(QUERY, fields: raw_fields)
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
