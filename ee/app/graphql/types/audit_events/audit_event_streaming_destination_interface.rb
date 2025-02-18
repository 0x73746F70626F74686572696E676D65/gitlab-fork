# frozen_string_literal: true

module Types
  module AuditEvents
    module AuditEventStreamingDestinationInterface
      include Types::BaseInterface

      field :id, GraphQL::Types::ID,
        null: false,
        description: 'ID of the destination.'

      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the external destination to send audit events to.'

      field :category, GraphQL::Types::String,
        null: false,
        description: 'Category of the external destination to send audit events to.'

      field :config, GraphQL::Types::JSON, # rubocop:disable Graphql/JSONType -- Different type of destinations will have different configs
        null: false,
        description: 'Config of the external destination.'

      field :event_type_filters, [GraphQL::Types::String],
        null: false,
        description: 'List of event type filters added for streaming.'
    end
  end
end
