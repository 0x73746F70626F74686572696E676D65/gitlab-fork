# frozen_string_literal: true

module Mutations
  module Ai
    module SelfHostedModels
      # rubocop: disable GraphQL/GraphqlName -- It's an abstraction not meant to be used in the schema
      class Base < BaseMutation
        field :self_hosted_model,
          Types::Ai::SelfHostedModels::SelfHostedModelType,
          null: true,
          description: 'Created self-hosted model.'

        private

        def check_feature_access!
          raise_resource_not_available_error! unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global

          raise_resource_not_available_error! unless Ability.allowed?(current_user, :manage_ai_settings)
        end
      end
      # rubocop: enable GraphQL/GraphqlName
    end
  end
end
