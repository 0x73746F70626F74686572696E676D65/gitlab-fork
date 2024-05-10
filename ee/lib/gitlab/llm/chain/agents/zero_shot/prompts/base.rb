# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        module ZeroShot
          module Prompts
            class Base
              def self.base_prompt(options)
                system_prompt = options[:system_prompt] || Utils::Prompt.default_system_prompt
                zero_shot_prompt = format(options[:zero_shot_prompt], options)

                Utils::Prompt.role_conversation([
                  Utils::Prompt.as_system(system_prompt, zero_shot_prompt),
                  Utils::Prompt.as_user(options[:user_input]),
                  Utils::Prompt.as_assistant(options[:agent_scratchpad], "Thought:")
                ])
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
