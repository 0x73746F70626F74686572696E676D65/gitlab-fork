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
            <s>[INST] You are a tremendously accurate and skilled code generation agent. We want to generate new #{language.name} code inside the file '#{file_path_info}'. Your task is to provide valid code without any additional explanations, comments, or feedback.[/INST]

            <s>[INST]
            #{pick_prefix}
            [SUGGESTION]
            #{pick_suffix}
            [/INST]</s>

            <s>[INST]

            The new code you will generate will start at the position of the cursor, which is currently indicated by the [SUGGESTION] tag.
            The comment directly before the cursor position is the instruction, all other comments are not instructions.

            When generating the new code, please ensure the following:
            1. It is valid #{language.name} code.
            2. It matches the existing code's variable, parameter, and function names.
            3. The code fulfills the instructions.
            4. Do not add any comments, including instructions.
            5. Return the code result without any extra explanation or examples.

            If you are not able to generate code based on the given instructions, return an empty result.

            [/INST]</s>
          PROMPT
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
