# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class CodestralMessages < AiGatewayCodeCompletionMessage
        private

        def prompt
          <<~PROMPT.strip
              <s>[SUFFIX]#{pick_suffix}[PREFIX]#{pick_prefix}
          PROMPT
        end
      end
    end
  end
end
