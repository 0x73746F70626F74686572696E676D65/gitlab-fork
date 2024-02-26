# frozen_string_literal: true

module Epics
  module EpicLinks
    class DestroyService < IssuableLinks::DestroyService
      attr_reader :child_epic, :parent_epic
      private :child_epic, :parent_epic

      def initialize(child_epic, user)
        @child_epic = child_epic
        @parent_epic = child_epic&.parent
        @current_user = user
      end

      private

      def remove_relation
        ::ApplicationRecord.transaction do
          child_epic.update!({ parent_id: nil, updated_by: current_user })
          destroy_work_item_parent_link!
        end
      end

      def create_notes
        return unless parent_epic

        SystemNoteService.change_epics_relation(parent_epic, child_epic, current_user, 'unrelate_epic')
      end

      def permission_to_remove_relation?
        child_epic.present? &&
          parent_epic.present? &&
          can?(current_user, :read_epic_relation, parent_epic) &&
          can?(current_user, :admin_epic_relation, child_epic)
      end

      def not_found_message
        'No Epic found for given params'
      end

      def destroy_work_item_parent_link!
        return unless child_epic.group.epic_synced_with_work_item_enabled?
        return unless child_epic.work_item.present?

        parent_link = child_epic.work_item.parent_link
        return unless parent_link.present?

        service_response = ::WorkItems::ParentLinks::DestroyService
                              .new(parent_link, current_user, { synced_work_item: true }).execute
        return if service_response[:status] == :success

        synced_work_item_error!(service_response[:message])
      end

      def synced_work_item_error!(error_msg)
        Gitlab::EpicWorkItemSync::Logger.error(
          message: 'Not able to remove epic parent', error_message: error_msg, group_id: child_epic.group.id,
          child_id: child_epic.id, parent_id: parent_epic.id
        )
        raise ActiveRecord::Rollback
      end
    end
  end
end
