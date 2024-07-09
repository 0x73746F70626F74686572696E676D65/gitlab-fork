# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class Base < Llm::Completions::Base
          def execute
            response = request!
            response_modifier = ResponseModifiers::Base.new(response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, resource, response_modifier, options: response_options
            ).execute
          end

          def agent_name
            raise NotImplementedError
          end

          def inputs
            raise NotImplementedError
          end

          private

          def request!
            ai_client = ::Gitlab::Llm::AiGateway::Client.new(user, service_name: prompt_message.ai_action.to_sym,
              tracking_context: tracking_context)
            ai_client.complete(
              endpoint: "/v1/agents/#{prompt_message.ai_action}/#{agent_name}",
              body: inputs
            )
          end
        end
      end
    end
  end
end
