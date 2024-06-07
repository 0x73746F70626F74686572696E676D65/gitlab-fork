# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class SelfHostedCodeCompletion < CodeSuggestions::Tasks::Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      def initialize(feature_setting:, **kwargs)
        @feature_setting = feature_setting

        super(**kwargs)
      end

      override :endpoint_name
      def endpoint_name
        'completions'
      end

      private

      attr_reader :feature_setting

      def params
        self_hosted_model = feature_setting.self_hosted_model

        super.merge({
          model_name: self_hosted_model.model,
          model_endpoint: self_hosted_model.endpoint
        })
      end

      def prompt
        CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages.new(params)
      end
      strong_memoize_attr :prompt
    end
  end
end
