# frozen_string_literal: true

module Gitlab
  module Llm
    module Completions
      class Base
        def initialize(prompt_message, ai_prompt_class, options = {})
          @prompt_message = prompt_message
          @ai_prompt_class = ai_prompt_class
          @options = options
        end

        private

        attr_reader :prompt_message, :ai_prompt_class, :options

        def user
          prompt_message.user
        end

        def resource
          prompt_message.resource
        end

        def response_options
          prompt_message.to_h.slice(:request_id, :client_subscription_id, :ai_action, :agent_version_id)
        end

        def tracking_context
          {
            request_id: prompt_message.request_id,
            action: prompt_message.ai_action
          }
        end

        def send_chunk(context, chunk)
          GraphqlTriggers.ai_completion_response(AiMessage.new({
            user: user,
            content: chunk[:content],
            chunk_id: chunk[:id],
            request_id: prompt_message.request_id,
            role: AiMessage::ROLE_ASSISTANT,
            client_subscription_id: response_options[:client_subscription_id],
            context: context
          }))
        end
      end
    end
  end
end
