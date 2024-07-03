# frozen_string_literal: true

module Search
  module Zoekt
    class Query
      include Gitlab::Utils::StrongMemoize
      SUPPORTED_SYNTAX_FILTERS = %w[case f file lang sym].freeze

      attr_reader :query

      def initialize(query)
        raise ArgumentError, 'query argument can not be nil' unless query

        @query = query
      end

      def exact_search_query
        exact_search_query = "\"#{RE2::Regexp.escape(keyword)}\""
        return exact_search_query if filters.empty?

        "#{exact_search_query} #{filters.join(' ')}"
      end

      private

      def keyword
        query.gsub(query_matcher_regex, '').strip
      end

      def filters
        @filters ||= query.scan(query_matcher_regex).flatten
      end

      def query_matcher_regex
        Regexp.union(SUPPORTED_SYNTAX_FILTERS.map { |filter| /-?#{filter}:\S+/ })
      end
      strong_memoize_attr(:query_matcher_regex)
    end
  end
end
