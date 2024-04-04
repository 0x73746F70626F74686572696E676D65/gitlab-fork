# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        module ZeroShot
          module Prompts
            class Base
              def self.base_prompt(options)
                return agent_version_prompt(options) if options[:agent_version_prompt]

                if options[:current_user] && Feature.enabled?(:ai_claude_3_sonnet, options[:current_user])
                  zero_shot_prompt = format(options[:zero_shot_prompt], options)

                  Utils::Prompt.role_conversation([
                    Utils::Prompt.as_system(Utils::Prompt.default_system_prompt, zero_shot_prompt),
                    Utils::Prompt.as_user(options[:user_input]),
                    Utils::Prompt.as_assistant(options[:agent_scratchpad], "Thought:")
                  ])
                else
                  base_prompt = Utils::Prompt.no_role_text(options.fetch(:prompt_version),
                    options
                  )

                  "#{Utils::Prompt.default_system_prompt}\n\n#{base_prompt}"
                end
              end

              def self.agent_version_prompt(options)
                base_prompt = Utils::Prompt.no_role_text(
                  [
                    Utils::Prompt.as_user("Question: %<user_input>s"),
                    Utils::Prompt.as_assistant("Thought: ")
                  ],
                  options
                )

                "#{options[:agent_version_prompt]}\n\n#{base_prompt}"
              end

              def self.current_blob_prompt(blob)
                <<~PROMPT
                The current code file that user sees is #{blob.path} and has the following content:
                <content>
                #{blob.data}
                </content>

                PROMPT
              end

              def self.current_selection_prompt(current_file_context)
                <<~PROMPT
                  User selected code below enclosed in <code></code> tags in file #{current_file_context[:file_name]} to work with:

                  <code>
                    #{current_file_context[:selected_text]}
                  </code>

                PROMPT
              end
            end
          end
        end
      end
    end
  end
end
