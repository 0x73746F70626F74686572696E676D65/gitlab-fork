# frozen_string_literal: true

module Types
  module Ai
    # rubocop: disable Graphql/AuthorizeTypes
    class AiResponseType < BaseObject
      graphql_name 'AiResponse'

      field :response_body, GraphQL::Types::String,
        null: true,
        description: 'Response body from AI API.'

      field :request_id, GraphQL::Types::String,
        null: true,
        description: 'ID of the original request.'

      field :role,
        Types::Ai::CachedMessageRoleEnum,
        null: false,
        description: 'Message role.'

      field :type, GraphQL::Types::String,
        null: true,
        description: 'Message type.'

      field :timestamp,
        Types::TimeType,
        null: false,
        description: 'Message timestamp.'

      field :errors, [GraphQL::Types::String],
        null: true,
        description: 'Errors return by AI API as response.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
