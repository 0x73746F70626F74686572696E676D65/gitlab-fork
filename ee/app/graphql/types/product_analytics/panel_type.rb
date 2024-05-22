# frozen_string_literal: true

# rubocop:disable Graphql/AuthorizeTypes
module Types
  module ProductAnalytics
    class PanelType < BaseObject
      graphql_name 'CustomizableDashboardPanel'
      description 'Represents a product analytics dashboard panel.'

      field :title,
        type: GraphQL::Types::String,
        null: true,
        description: 'Title of the panel.'

      field :grid_attributes,
        type: GraphQL::Types::JSON,
        null: true,
        description: 'Description of the position and size of the panel.'

      field :query_overrides,
        type: GraphQL::Types::JSON,
        null: true,
        description: 'Overrides for the visualization query object.'

      field :visualization,
        type: Types::ProductAnalytics::VisualizationType,
        null: true,
        description: 'Visualization of the panel.',
        resolver: Resolvers::ProductAnalytics::VisualizationResolver
    end
  end
end
# rubocop:enable Graphql/AuthorizeTypes
