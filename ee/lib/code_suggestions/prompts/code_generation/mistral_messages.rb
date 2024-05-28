# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeGeneration
      class MistralMessages < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 3
        MODEL_PROVIDER = 'litellm'

        def request_params
          {
            model_provider: self.class::MODEL_PROVIDER,
            prompt_version: self.class::GATEWAY_PROMPT_VERSION,
            prompt: prompt,
            model_endpoint: params[:model_endpoint]
          }.tap do |opts|
            opts[:model_name] = params[:model_name] if params[:model_name].present?
            opts[:model_api_key] = params[:model_api_key] if params[:model_api_key].present?
          end
        end

        private

        def prompt
          [
            { role: :user, content: instructions }
          ]
        end

        def instructions
          <<~PROMPT.strip
            <s>[INST] You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new #{language.name} code inside the file '#{file_path_info}'. Your task is to provide a valid replacement for [SUGGESTION] without any additional code, comments or explanation. #{examples_section}[/INST]</s>

            [INST]
            #{pick_prefix}
            [SUGGESTION]
            #{pick_suffix}
            [/INST]

            [INST]
            The new code you will generate will start at the position of the cursor, which is currently indicated by the [SUGGESTION] tag.
            In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
            likely new code to generate at the cursor position to fulfill the instructions.

            The comment directly before the cursor position is the instruction,
            all other comments are not instructions.

            When generating the new code, please ensure the following:
            1. It is valid #{language.name} code.
            2. It matches the existing code's variable, parameter and function names.
            3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
            4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
            5. The code fulfills in the instructions from the user in the comment just before the [SUGGESTION] position. All other comments are not instructions.
            6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

            If you are not able to write code based on the given instructions return an empty result.
            Don't return any text, just return the code results without extra explanation.
            [/INST]
          PROMPT
        end

        def examples_section
          examples_template = <<~EXAMPLES
          Here are a few examples of successfully generated code:

          <% examples_array.each do |use_case| %>
            <s>[INST] <%= use_case['example'].gsub('{{cursor}}', '[SUGGESTION]') %> [/INST]
            <%= use_case['response'].gsub('<new_code>', '') %>
            </s>
          <% end %>
          EXAMPLES

          examples_array = language.generation_examples(type: params[:instruction]&.trigger_type)
          return if examples_array.empty?

          ERB.new(examples_template).result(binding)
        end

        def pick_prefix
          prefix.last(500)
        end

        def pick_suffix
          suffix.first(500)
        end
      end
    end
  end
end
