# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class CodeGemmaMessages < AiGatewayCodeCompletionMessage
        private

        def prompt
          <<~PROMPT.strip
            <|fim_prefix|>#{pick_prefix}<|fim_suffix|>#{pick_suffix}<|fim_middle|>
          PROMPT
        end
      end
    end
  end
end
