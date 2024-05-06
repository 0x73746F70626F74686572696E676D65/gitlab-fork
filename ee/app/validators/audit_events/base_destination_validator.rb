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

    def validate_attribute_uniqueness(record, attribute_name, category)
      existing_configs = configs(record, category)

      existing_configs.each do |existing_config|
        if existing_config[attribute_name] == record.config[attribute_name]
          record.errors.add(:config, format(_("%{attribute} is already taken."), attribute: attribute_name))
          break
        end
      end
    end
  end
end
