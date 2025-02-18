# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module IssueReader
          module Prompts
            class VertexAi
              def self.prompt(options)
                prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::IssueReader::Executor::PROMPT_TEMPLATE, options
                )

                Requests::VertexAi.prompt(prompt)
              end
            end
          end
        end
      end
    end
  end
end
