# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class Response # rubocop:disable Search/NamespacedClass -- we want to have this class in the same namespace as the client
        attr_reader :parsed_response

        def initialize(response)
          @parsed_response = response.with_indifferent_access
        end

        def success?
          error_message.nil?
        end

        def failure?
          !!error_message
        end

        def error_message
          parsed_response[:Error]
        end

        def result
          parsed_response[:Result]
        end

        def file_count
          result[:FileCount]
        end

        def match_count
          result[:MatchCount]
        end

        def ngram_match_count
          result[:NgramMatches]
        end

        def each_file
          files = result[:Files] || []

          files.each do |file|
            yield file
          end
        end
      end
    end
  end
end
