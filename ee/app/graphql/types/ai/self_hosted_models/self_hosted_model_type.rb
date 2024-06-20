# frozen_string_literal: true

module Types
  module Ai
    module SelfHostedModels
      # rubocop: disable Graphql/AuthorizeTypes -- authorization in resolver/mutation
      class SelfHostedModelType < ::Types::BaseObject
        graphql_name 'AiSelfHostedModel'
        description 'Self-hosted LLM servers'

        field :created_at, Types::TimeType, null: false, description: 'Timestamp of creation.'
        field :endpoint, String, null: false, description: 'Endpoint of the self-hosted model server.'
        field :has_api_token, Boolean,
          null: false,
          description: 'Indicates if an API key is set for the self-hosted model server.'
        field :id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          null: false,
          description: 'ID of the self-hosted model server.'
        field :model, String, null: false, description: 'AI model deployed.'
        field :name, String, null: false, description: 'Deployment name of the self-hosted model.'
        field :updated_at, Types::TimeType, null: true, description: 'Timestamp of last update.'

        def has_api_token # rubocop:disable Naming/PredicateName -- otherwise resolver matcher don't work
          object.api_token.present?
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
