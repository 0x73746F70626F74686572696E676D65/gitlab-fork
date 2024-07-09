# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module ResponseModifiers
        class Base < Gitlab::Llm::BaseResponseModifier
          def initialize(ai_response)
            @ai_response = Gitlab::Json.parse(ai_response.body)
          end

          def response_body
            ai_response
          end

          def errors
            # On success, the response is just a plain JSON string
            @errors ||= if ai_response.is_a?(String)
                          []
                        else
                          detail = ai_response&.dig('detail')

                          [detail.is_a?(String) ? detail : detail&.dig(0, 'msg')].compact
                        end
          end
        end
      end
    end
  end
end
