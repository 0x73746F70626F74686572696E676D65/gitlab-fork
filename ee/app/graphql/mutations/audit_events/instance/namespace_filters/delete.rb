# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module NamespaceFilters
        class Delete < Base
          graphql_name 'AuditEventsInstanceDestinationNamespaceFilterDelete'

          argument :namespace_filter_id, ::Types::GlobalIDType[::AuditEvents::Instance::NamespaceFilter],
            required: true,
            description: 'Namespace filter ID.'
          def resolve(namespace_filter_id:)
            filter = authorized_find!(id: namespace_filter_id)

            audit(filter, action: :deleted) if filter.destroy

            { namespace_filter: nil, errors: filter.errors }
          end
        end
      end
    end
  end
end
