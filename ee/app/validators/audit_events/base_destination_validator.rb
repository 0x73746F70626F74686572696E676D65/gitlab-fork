# frozen_string_literal: true

module AuditEvents
  class BaseDestinationValidator < ActiveModel::Validator
    private

    def configs(record, category)
      destinations = if record.is_a?(AuditEvents::Group::ExternalStreamingDestination)
                       record.group.external_audit_event_streaming_destinations
                     else
                       AuditEvents::Instance::ExternalStreamingDestination.all.limit(
                         AuditEvents::ExternallyStreamable::MAXIMUM_DESTINATIONS_PER_ENTITY)
                     end

      destinations.configs_of_parent(record.id, category)
    end
  end
end
