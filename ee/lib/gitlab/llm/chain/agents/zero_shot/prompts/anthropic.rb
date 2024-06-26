# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        module ZeroShot
          module Prompts
            class Anthropic < Base
              include Concerns::AnthropicPrompt
              extend Langsmith::RunHelpers

              def self.prompt(options)
                history = truncated_conversation_list(options[:conversation])
                base = base_prompt(options)

                text = deduplicate_roles(history + base)

                Requests::Anthropic.prompt(text)
              end
              traceable :prompt, name: 'Build prompt', run_type: 'prompt', class_method: true

              def self.truncated_conversation_list(conversation)
                # We save a maximum of 50 chat history messages
                # We save a max of 20k chars for each message prompt (~5k
                # tokens)
                # Response from Anthropic is max of 4096 tokens
                # So the max tokens we would ever send 9k * 50 = 450k tokens.
                # Max context window is 200k.
                # For now, no truncating actually happening here but we should
                # do that to make sure we stay under the limit.
                # https://gitlab.com/gitlab-org/gitlab/-/issues/452608
                return [] if conversation.blank?

                conversation.map do |message, _|
                  { role: message.role.to_sym, content: message.content }
                end
              end

              def self.deduplicate_roles(messages)
                result = []
                previous_role = nil

                messages.each do |message|
                  current_role = message[:role]
                  current_content = message[:content]

                  if current_role == previous_role
                    # If the current role is the same as the previous one, update the content
                    result.last[:content] = current_content
                  else
                    # If the role is different, add a new entry
                    result << { role: current_role, content: current_content }
                    previous_role = current_role
                  end
                end

                result
              end
            end
          end
        end
      end
    end
  end
end
