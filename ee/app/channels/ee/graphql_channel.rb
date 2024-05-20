# frozen_string_literal: true

module EE
  module GraphqlChannel
    extend ActiveSupport::Concern

    prepended do
      def authorization_scopes
        # rubocop:disable Gitlab/FeatureFlagWithoutActor -- this is before we auth the user and we may not have project
        if ::Feature.enabled?(:allow_ai_features_token_for_graphql_ai_features)
          super + [:ai_features]
        else
          super
        end
        # rubocop:enable Gitlab/FeatureFlagWithoutActor
      end
    end
  end
end
