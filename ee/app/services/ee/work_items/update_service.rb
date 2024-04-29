# frozen_string_literal: true

module EE
  module WorkItems
    module UpdateService
      extend ::Gitlab::Utils::Override
      include ::WorkItems::SyncAsEpic

      private

      attr_reader :widget_params, :callbacks

      def transaction_update(work_item, opts = {})
        return super if sync_work_item?
        return super unless work_item.epic_work_item?

        super.tap do |save_result|
          break save_result unless save_result

          update_epic_for!(work_item)
        end
      end

      override :create_system_notes
      def create_system_notes(issuable, **options)
        super unless sync_work_item?
      end

      override :filter_timestamp_params
      def filter_timestamp_params
        super unless sync_work_item?
      end

      override :assign_last_edited
      def assign_last_edited(work_item)
        return super unless sync_work_item?

        work_item.assign_attributes(last_edited_at: params[:last_edited_at], last_edited_by: params[:last_edited_by])
      end

      override :handle_confidential_change
      def handle_confidential_change(work_item)
        # We don't want to delete todos, or create a confidential note as part of a synced work item update.
        # Once the work item is synced from the epic, we want to re-assign the notes and todos to the new work item.
        super unless sync_work_item?
      end

      override :can_set_confidentiality?
      def can_set_confidentiality?(work_item)
        return true if sync_work_item?

        super
      end

      def sync_work_item?
        extra_params&.fetch(:synced_work_item, false)
      end
    end
  end
end
