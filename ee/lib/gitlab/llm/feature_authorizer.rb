# frozen_string_literal: true

module Gitlab
  module Llm
    class FeatureAuthorizer
      def initialize(container:, feature_name:)
        @container = container
        @feature_name = feature_name
      end

      def allowed?
        return false unless Feature.enabled?(:ai_global_switch, type: :ops)
        return false unless container&.duo_features_enabled

        ::Gitlab::Llm::StageCheck.available?(container, feature_name)
      end

      private

      attr_reader :container, :feature_name
    end
  end
end
