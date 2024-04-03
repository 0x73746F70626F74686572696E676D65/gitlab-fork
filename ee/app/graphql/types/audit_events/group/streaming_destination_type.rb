# frozen_string_literal: true

module Types
  module AuditEvents
    module Group
      class StreamingDestinationType < ::Types::BaseObject
        graphql_name 'GroupAuditEventStreamingDestination'
        description 'Represents an external destination to stream group level audit events.'
        authorize :admin_external_audit_events

        implements AuditEventStreamingDestinationInterface

        field :group, ::Types::GroupType,
          null: false,
          description: 'Group to which the destination belongs.'
      end
    end
  end
end
