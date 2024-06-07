# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class CodeGemmaMessages < CodeSuggestions::Prompts::Base
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
          <<~PROMPT.strip
            <|fim_prefix|>#{pick_prefix}<|fim_suffix|>#{pick_suffix}<|fim_middle|>
          PROMPT
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
