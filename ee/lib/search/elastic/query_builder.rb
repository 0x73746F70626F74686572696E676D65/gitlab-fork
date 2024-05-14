# frozen_string_literal: true

module Search
  module Elastic
    class QueryBuilder
      include ::Elastic::Latest::QueryContext::Aware

      def self.build(...)
        new(...).build
      end

      def initialize(query:, options: {})
        @query = query
        @options = options.merge(extra_options)
      end

      def build
        raise NotImplementedError
      end

      private

      attr_reader :query, :options

      # Subclasses should override this method to provide additional options to builder
      def extra_options
        {}
      end
    end
  end
end
