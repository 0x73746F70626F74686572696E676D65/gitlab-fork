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

      override :service_name
      def feature_name
        :self_hosted_models
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
        model_name = feature_setting.self_hosted_model.model.to_sym
        case model_name
        when :codegemma
          CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages.new(params)
        when :codestral
          CodeSuggestions::Prompts::CodeCompletion::CodestralMessages.new(params)
        else
          raise "Unknown model: #{model_name}"
        end
      end
      strong_memoize_attr :prompt
    end
  end
end
