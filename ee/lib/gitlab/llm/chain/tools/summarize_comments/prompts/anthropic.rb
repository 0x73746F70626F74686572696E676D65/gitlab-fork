# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module SummarizeComments
          module Prompts
            class Anthropic
              include Concerns::AnthropicPrompt

              OUTPUT_TOKEN_LIMIT = 8000

              def self.prompt(options)
                base_prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::SummarizeComments::Executor::PROMPT_TEMPLATE, options
                )

                Requests::Anthropic.prompt(
                  "\n\nHuman: #{base_prompt}\n\nAssistant:",
                  options: {
                    model: ::Gitlab::Llm::Anthropic::Client::DEFAULT_INSTANT_MODEL,
                    max_tokens_to_sample: OUTPUT_TOKEN_LIMIT
                  }
                )
              end
            end
          end
        end
      end
    end
  end
end
