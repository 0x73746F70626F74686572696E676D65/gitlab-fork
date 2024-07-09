# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class MultiNodeResponse # rubocop:disable Search/NamespacedClass -- we want to have this class in the same namespace as the client
        attr_reader :responses_hash

        def initialize(responses)
          @responses_hash = responses
        end

        def responses
          @responses ||= responses_hash.values
        end

        def success?
          responses.all?(&:success?)
        end

        def failure?
          responses.any?(&:failure?)
        end

        def error_message
          errors = responses.filter_map(&:error_message)
          return if errors.empty?

          errors.join(',')
        end

        def file_count
          responses.sum(&:file_count)
        end

        def match_count
          responses.sum(&:match_count)
        end

        def each_file
          files = responses_hash.transform_values { |m| m.result[:Files] }.select { |_, files| files.present? }
          idx = Hash.new(0)

          loop do
            next_node_id = files.max_by { |node_id, f| f.dig(idx[node_id], 'Score').to_f }&.first
            file = files.dig(next_node_id, idx[next_node_id])
            break unless file

            yield file

            idx[next_node_id] += 1
          end
        end
      end
    end
  end
end
