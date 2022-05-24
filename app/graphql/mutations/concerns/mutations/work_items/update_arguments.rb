# frozen_string_literal: true

module Mutations
  module WorkItems
    module UpdateArguments
      extend ActiveSupport::Concern

      included do
        argument :id, ::Types::GlobalIDType[::WorkItem],
                 required: true,
                 description: 'Global ID of the work item.'
        argument :state_event, Types::WorkItems::StateEventEnum,
                 description: 'Close or reopen a work item.',
                 required: false
        argument :title, GraphQL::Types::String,
                 required: false,
                 description: copy_field_description(Types::WorkItemType, :title)
      end
    end
  end
end
