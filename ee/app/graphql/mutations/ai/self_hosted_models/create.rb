# frozen_string_literal: true

module Mutations
  module Ai
    module SelfHostedModels
      class Create < Base
        graphql_name 'AiSelfHostedModelCreate'

        argument :name, GraphQL::Types::String,
          required: true,
          description: 'Deployment name of the self-hosted model.'

        argument :model, ::Types::Ai::SelfHostedModels::AcceptedModelsEnum,
          required: true,
          description: 'AI model deployed.'

        argument :endpoint, GraphQL::Types::String,
          required: true,
          description: 'Endpoint of the self-hosted model.'

        argument :api_token, GraphQL::Types::String,
          required: false,
          description: 'API token to access the self-hosted model, if any.'

        def resolve(**args)
          check_feature_access!

          # TODO: We should create a service this is done for MVP sake
          model = ::Ai::SelfHostedModel.create!(
            name: args[:name],
            model: args[:model],
            endpoint: args[:endpoint],
            api_token: args[:api_token]
          )

          {
            self_hosted_model: model,
            errors: errors_on_object(model)
          }
        end
      end
    end
  end
end
