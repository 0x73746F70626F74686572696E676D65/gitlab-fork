# frozen_string_literal: true

module Search
  module Elastic
    module Formats
      class << self
        def size(query_hash:, options:)
          return query_hash unless options[:count_only]

          query_hash.merge(size: 0)
        end

        def source_fields(query_hash:, options:)
          return query_hash unless options[:source_fields]

          query_hash.merge(_source: options[:source_fields])
        end
      end
    end
  end
end
