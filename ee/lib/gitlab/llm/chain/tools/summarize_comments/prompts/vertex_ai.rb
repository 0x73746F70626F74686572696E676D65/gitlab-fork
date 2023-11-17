# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module SummarizeComments
          module Prompts
            class VertexAi
              include Concerns::VertexAiPrompt

              OUTPUT_TOKEN_LIMIT = 1024

              def self.prompt(options)
                prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::SummarizeComments::Executor::PROMPT_TEMPLATE, options
                )

                {
                  prompt: prompt,
                  options: {
                    max_output_tokens: OUTPUT_TOKEN_LIMIT
                  }
                }
              end
            end
          end
        end
      end
    end
  end
end
