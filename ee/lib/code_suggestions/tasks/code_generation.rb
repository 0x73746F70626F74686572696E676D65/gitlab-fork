# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeGeneration < CodeSuggestions::Tasks::Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      override :endpoint_name
      def endpoint_name
        'generations'
      end

      private

      def prompt
        CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages.new(params)
      end
      strong_memoize_attr :prompt
    end
  end
end
