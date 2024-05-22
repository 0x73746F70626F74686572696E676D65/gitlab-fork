# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module CiEditorAssistant
          module Prompts
            class Anthropic
              include Concerns::AnthropicPrompt

              MODEL = 'claude-2.1'

              def self.claude_3_prompt(options)
                system_template = ::Gitlab::Llm::Chain::Tools::CiEditorAssistant::Executor::SYSTEM_TEMPLATE
                user_template = Utils::Prompt.as_user(options[:input])
                assistant_template = Utils::Prompt.as_assistant('```yaml')
                conversation = Utils::Prompt.role_conversation([system_template, user_template, assistant_template])

                { prompt: conversation }
              end

              def self.prompt(options)
                template = [::Gitlab::Llm::Chain::Tools::CiEditorAssistant::Executor::SYSTEM_TEMPLATE,
                  ::Gitlab::Llm::Chain::Tools::CiEditorAssistant::Executor::USER_TEMPLATE,
                  Utils::Prompt.as_assistant('```yaml')]
                base_prompt = Utils::Prompt.role_text(template, options, roles: ROLE_NAMES)

                {
                  prompt: base_prompt,
                  options: { model: MODEL }
                }
              end
            end
          end
        end
      end
    end
  end
end
