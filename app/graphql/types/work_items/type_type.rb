# frozen_string_literal: true

module Types
  module WorkItems
    class TypeType < BaseObject
      graphql_name 'WorkItemType'

      authorize :read_work_item_type

      field :icon_name, GraphQL::Types::String,
        null: true,
        description: 'Icon name of the work item type.'
      field :id, Types::GlobalIDType[::WorkItems::Type],
        null: false,
        description: 'Global ID of the work item type.'
      field :name, GraphQL::Types::String,
        null: false,
        description: 'Name of the work item type.'
      field :widget_definitions, [Types::WorkItems::WidgetDefinitionInterface],
        null: true,
        description: 'Available widgets for the work item type.',
        method: :widgets,
        alpha: { milestone: '16.7' }

      def widget_definitions
        object.widgets(context[:resource_parent])
      end
    end
  end
end
