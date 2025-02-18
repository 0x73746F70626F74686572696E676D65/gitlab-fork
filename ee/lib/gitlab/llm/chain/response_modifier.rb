# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      class ResponseModifier < Gitlab::Llm::BaseResponseModifier
        def initialize(answer)
          @ai_response = answer
        end

        def response_body
          @response_body ||= ai_response.content
        end

        def extras
          @extras ||= ai_response.extras
        end

        def errors
          @errors ||= ai_response.status == :error ? [error_message] : []
        end

        private

        def error_message
          message = ai_response.content
          message += " #{_('Error code')}: #{ai_response.error_code}" if ai_response.error_code.present?
          message
        end
      end
    end
  end
end
