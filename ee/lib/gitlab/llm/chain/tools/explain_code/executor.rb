# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module ExplainCode
          class Executor < SlashCommandTool
            extend ::Gitlab::Utils::Override
            include Concerns::AiDependent

            NAME = 'ExplainCode'
            HUMAN_NAME = 'Explain Code'
            DESCRIPTION = 'Useful tool to explain code snippets and blocks.'
            RESOURCE_NAME = nil
            EXAMPLE = "Question: How would you improve the " \
                      "```def hello_world\nputs('Hello, world!\\n\');\nend``` code? " \
                      'Picked tools: "ExplainCode" tool. ' \
                      'Reason: The question has a code block that needs improvement. "ExplainCode" tool ' \
                      'can process this question.'
            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Tools::ExplainCode::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Tools::ExplainCode::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Tools::ExplainCode::Prompts::VertexAi
            }.freeze

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                  You are a software developer.
                  You can explain code snippets.
                  %<language_info>s
                PROMPT
              ),
              Utils::Prompt.as_user("%<file_content>s"),
              Utils::Prompt.as_user(
                <<~PROMPT
                  Here is the code user selected:
                  <selected_code>
                    %<selected_text>s
                  </selected_code>
                PROMPT
              ),
              Utils::Prompt.as_user("%<input>s"),
              Utils::Prompt.as_user('Any code blocks in response should be formatted in markdown.')
            ].freeze

            SLASH_COMMANDS = {
              '/explain' => {
                description: 'Explain the code',
                instruction: 'Explain the code user selected inside <selected_code></selected_code> tags.',
                instruction_with_input: 'Explain %<input>s user selected inside <selected_code></selected_code> tags.'
              }
            }.freeze

            def self.slash_commands
              SLASH_COMMANDS
            end

            private

            def authorize
              Utils::ChatAuthorizer.context(context: context).allowed?
            end

            def resource_name
              nil
            end
          end
        end
      end
    end
  end
end
