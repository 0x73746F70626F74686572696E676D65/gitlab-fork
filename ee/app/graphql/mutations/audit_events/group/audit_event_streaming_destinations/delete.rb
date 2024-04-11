# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Group
      module AuditEventStreamingDestinations
        class Delete < Base
          graphql_name 'GroupAuditEventStreamingDestinationsDelete'

          argument :id, ::Types::GlobalIDType[::AuditEvents::Group::ExternalStreamingDestination],
            required: true,
            description: 'ID of the audit events external streaming destination to delete.'

          def resolve(id:)
            config = authorized_find!(id: id)

            audit(config, action: :deleted) if config.destroy
            { errors: Array(config.errors) }
          end
        end
      end
    end
  end
end
