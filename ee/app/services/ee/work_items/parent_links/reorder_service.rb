# frozen_string_literal: true

module EE
  module WorkItems
    module ParentLinks
      module ReorderService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        def execute
          super
        rescue ::WorkItems::SyncAsEpic::SyncAsEpicError => _error
          error(_("Couldn't re-order due to an internal error."), 422)
        end

        private

        override :move_link
        def move_link(link, adjacent_work_item, relative_position)
          create_missing_synced_link!(adjacent_work_item)
          return unless adjacent_work_item.parent_link

          return super unless sync_to_epic?(link, adjacent_work_item)

          ApplicationRecord.transaction do
            move_synced_object!(link, adjacent_work_item, relative_position) if super
          end
        end

        def create_missing_synced_link!(adjacent_work_item)
          adjacent_parent_link = adjacent_work_item.parent_link
          # if issuable is an epic, we can create the missing parent link between epic work item and adjacent_work_item
          return unless adjacent_parent_link.blank? && adjacent_work_item.synced_epic

          adjacent_parent_link = set_parent(issuable, adjacent_work_item)
          adjacent_parent_link.relative_position = adjacent_work_item.synced_epic.relative_position
          adjacent_parent_link.save!

          # we update the adjacent_work_item's parent link but use the adjacent_work_item object.
          adjacent_work_item.reset
        end

        def move_synced_object!(link, adjacent_work_item, relative_position)
          synced_moving_object = synced_object_for(link.work_item)
          synced_adjacent_object = synced_object_for(adjacent_work_item)

          synced_moving_object.move_before(synced_adjacent_object) if relative_position == 'BEFORE'
          synced_moving_object.move_after(synced_adjacent_object) if relative_position == 'AFTER'

          synced_moving_object.save!(touch: false)
        rescue StandardError => error
          ::Gitlab::EpicWorkItemSync::Logger.error(
            message: "Not able to sync re-ordering work item",
            error_message: error.message,
            namespace_id: issuable.namespace_id,
            synced_moving_object_id: synced_moving_object.id,
            synced_moving_object_class: synced_moving_object.class
          )

          ::Gitlab::ErrorTracking.track_exception(error, namespace_id: issuable.namespace_id)

          raise ::WorkItems::SyncAsEpic::SyncAsEpicError
        end

        def synced_object_for(work_item)
          case work_item.synced_epic
          when nil
            ::EpicIssue.find_by_issue_id(work_item.id)
          when ::Epic
            work_item.synced_epic
          end
        end

        def sync_to_epic?(link, adjacent_work_item)
          return false if synced_work_item
          return false if link.work_item_parent.synced_epic.nil?

          synced_object_for(link.work_item) && synced_object_for(adjacent_work_item)
        end

        override :can_admin_link?
        def can_admin_link?(work_item)
          return true if synced_work_item
          return false if work_item.work_item_type.epic? && !work_item.namespace.licensed_feature_available?(:subepics)

          super
        end
      end
    end
  end
end
