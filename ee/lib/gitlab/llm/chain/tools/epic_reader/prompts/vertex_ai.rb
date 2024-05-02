# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module EpicReader
          module Prompts
            class VertexAi
              include Concerns::VertexAiPrompt

              def self.prompt(options)
                prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::EpicReader::Executor::PROMPT_TEMPLATE, options
                )

                {
                  prompt: prompt,
                  options: {}
                }
              end
            end
          end
        end
      end
    end
  end
end
