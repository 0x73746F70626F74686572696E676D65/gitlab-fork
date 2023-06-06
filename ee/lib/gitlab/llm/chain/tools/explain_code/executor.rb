# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module ExplainCode
          class Executor < Tool
            include Concerns::AiDependent

            NAME = 'ExplainCode'
            DESCRIPTION = 'Useful tool to explain code snippets.'
            PROVIDER_PROMPT_CLASSES = {
              anthropic: ::Gitlab::Llm::Chain::Tools::ExplainCode::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Tools::ExplainCode::Prompts::VertexAi
            }.freeze

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                  You are a software developer.
                  You can explain code snippets.
                  The code can be in any programming language.
                  Explain the code below.
                PROMPT
              ),
              Utils::Prompt.as_user("%<input>s")
            ].freeze

            def execute
              Answer.new(status: :ok, context: context, content: request, tool: nil)
            rescue StandardError
              Answer.error_answer(context: context, content: _("Unexpected error"))
            end
          end
        end
      end
    end
  end
end
