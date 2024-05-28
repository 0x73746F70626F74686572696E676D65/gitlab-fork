# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class SelfHostedCodeGeneration < CodeSuggestions::Tasks::Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      def initialize(feature_setting:, **kwargs)
        @feature_setting = feature_setting

        super(**kwargs)
      end

      override :endpoint_name
      def endpoint_name
        'generations'
      end

      private

      attr_reader :feature_setting

      def params
        self_hosted_model = feature_setting.self_hosted_model

        super.merge({
          model_name: self_hosted_model.model,
          model_endpoint: self_hosted_model.endpoint,
          model_api_key: self_hosted_model.api_token
        })
      end

      def prompt
        CodeSuggestions::Prompts::CodeGeneration::MistralMessages.new(params)
      end
      strong_memoize_attr :prompt
    end
  end
end
