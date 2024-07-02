# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module CiEditorAssistant
          module Prompts
            class Anthropic
              include Concerns::AnthropicPrompt

              def self.prompt(options)
                system_template = ::Gitlab::Llm::Chain::Tools::CiEditorAssistant::Executor::SYSTEM_TEMPLATE
                user_template = Utils::Prompt.as_user(options[:input])
                assistant_template = Utils::Prompt.as_assistant('```yaml')
                conversation = Utils::Prompt.role_conversation([system_template, user_template, assistant_template])

                { prompt: conversation }
              end
            end
          end
        end
      end
    end
  end
end
