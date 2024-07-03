# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class AiGatewayCodeCompletionMessage < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2
        MODEL_PROVIDER = 'litellm'

        def request_params
          {
            model_provider: self.class::MODEL_PROVIDER,
            prompt_version: self.class::GATEWAY_PROMPT_VERSION,
            prompt: prompt,
            model_endpoint: params[:model_endpoint]
          }.tap do |opts|
            opts[:model_name] = params[:model_name] if params[:model_name].present?
          end
        end

        private

        def prompt
          raise NotImplementedError, "#{self.class} has not implemented method #{__method__}"
        end

        def pick_prefix
          prefix.last(500)
        end

        def pick_suffix
          suffix.first(500)
        end
      end
    end
  end
end
