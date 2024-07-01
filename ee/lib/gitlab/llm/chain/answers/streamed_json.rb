# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Answers
        class StreamedJson < StreamedAnswer
          def initialize
            @final_answer_started = false
            @full_message = ''

            super
          end

          def next_chunk(content)
            return if content.empty?

            content = ::Gitlab::Json.parse(content)
            answer_chunk = final_answer_chunk(content)

            return unless answer_chunk
            return payload(answer_chunk) if final_answer_started

            @full_message += answer_chunk

            return unless final_answer_start(content)

            @final_answer_started = true
            payload(answer_chunk)
          end

          private

          attr_accessor :full_message, :final_answer_started

          def final_answer_start(content)
            'final_answer_delta' == content['type']
          end

          def final_answer_chunk(content)
            content.dig('data', 'text')
          end
        end
      end
    end
  end
end
