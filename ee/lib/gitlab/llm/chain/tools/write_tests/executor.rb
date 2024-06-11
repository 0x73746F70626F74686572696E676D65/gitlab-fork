# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module WriteTests
          class Executor < SlashCommandTool
            extend ::Gitlab::Utils::Override
            include Concerns::AiDependent

            NAME = 'WriteTests'
            HUMAN_NAME = 'Write Tests'
            DESCRIPTION = 'Useful tool to write tests for source code.'
            RESOURCE_NAME = nil
            ACTION = 'generate tests for'
            EXAMPLE = <<~TEXT
              Question: Write tests for this code
              ```
              def hello_world
                puts('Hello, world!')
              end
              ```
              Picked tools: "WriteTests" tool.
              Reason: The question has a code block for which we want to write tests. "WriteTests" tool can process this question.
            TEXT
            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Tools::WriteTests::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Tools::WriteTests::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Tools::WriteTests::Prompts::VertexAi
            }.freeze

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                  You are a software developer.
                  You can write new tests.
                  %<language_info>s
                PROMPT
              ),
              Utils::Prompt.as_user(
                <<~PROMPT.chomp
                  %<file_content>s
                  In the file user selected this code:
                  <selected_code>
                    %<selected_text>s
                  </selected_code>

                  %<input>s
                  Any code blocks in response should be formatted in markdown.
                PROMPT
              )
            ].freeze

            SLASH_COMMANDS = {
              '/tests' => {
                description: 'Write tests for the code',
                instruction: 'Write tests for the code user selected inside <selected_code></selected_code> tags.',
                instruction_with_input: 'Write tests %<input>s for the code user selected inside ' \
                                        '<selected_code></selected_code> tags.'
              }
            }.freeze

            def self.slash_commands
              SLASH_COMMANDS
            end

            private

            def authorize
              Utils::ChatAuthorizer.context(context: context).allowed?
            end
          end
        end
      end
    end
  end
end
