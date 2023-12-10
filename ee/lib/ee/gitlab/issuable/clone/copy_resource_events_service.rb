# frozen_string_literal: true

module EE
  module Gitlab
    module Issuable
      module Clone
        module CopyResourceEventsService
          extend ::Gitlab::Utils::Override

          override :execute
          def execute
            super

            copy_resource_weight_events
            copy_resource_iteration_events
          end

          private

          override :blocked_state_event_attributes
          def blocked_state_event_attributes
            super.push('issue_id')
          end

          def copy_resource_weight_events
            return unless both_respond_to?(:resource_weight_events)

            copy_events(ResourceWeightEvent.table_name, original_entity.resource_weight_events) do |event|
              event.attributes.except('id').merge('issue_id' => new_entity.id)
            end
          end

          def copy_resource_iteration_events
            return unless both_respond_to?(:resource_iteration_events)

            copy_events(ResourceIterationEvent.table_name, original_entity.resource_iteration_events) do |event|
              event.attributes.except('id').merge(
                'issue_id' => new_entity.id,
                'action' => ResourceIterationEvent.actions[event.action]
              )
            end
          end

          override :group
          def group
            if new_entity.respond_to?(:group) && new_entity.group
              new_entity.group
            else
              super
            end
          end
        end
      end
    end
  end
end
