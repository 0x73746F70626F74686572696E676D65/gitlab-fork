# frozen_string_literal: true

module Resolvers
  module Ai
    module SelfHostedModels
      class SelfHostedModelsResolver < BaseResolver
        type ::Types::Ai::SelfHostedModels::SelfHostedModelType.connection_type, null: false

        def resolve(**_args)
          return unless Feature.enabled?(:ai_custom_model) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
          return unless Ability.allowed?(current_user, :manage_ai_settings)

          ::Ai::SelfHostedModel.all
        end
      end
    end
  end
end
