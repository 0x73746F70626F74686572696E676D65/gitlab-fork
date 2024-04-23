# frozen_string_literal: true

module EE
  module Issues
    module CloseService
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      private

      override :perform_incident_management_actions
      def perform_incident_management_actions(issue)
        super
        update_issuable_sla(issue)
      end

      override :handle_closing_issue!
      def handle_closing_issue!(issue, current_user)
        return super unless sync_to_epic?(issue)

        ApplicationRecord.transaction do
          next false unless super

          # In case the epic and work item went out of sync but the epic is closed, we don't want to error but
          # keep both in sync again.
          issue.synced_epic.close! if issue.synced_epic.open?

          # Using `issue` here because `super` calls `close!` on the `issue` object
          issue.synced_epic.update!(closed_at: issue.closed_at, closed_by: issue.closed_by)
        end
      rescue StandardError => error
        ::Gitlab::EpicWorkItemSync::Logger.error(
          message: "Not able to sync closing epic work item",
          error_message: error.message,
          work_item_id: issue.id)

        ::Gitlab::ErrorTracking.track_and_raise_exception(error, work_item_id: issue.id)
      end

      override :after_close
      def after_close(issue, closed_via: nil, notifications: true, system_note: true)
        return super unless sync_to_epic?(issue)

        super
        # Creating a system note changes `updated_at` for the issue
        issue.synced_epic.update_column(:updated_at, issue.updated_at)
      end

      def sync_to_epic?(issue)
        return false unless issue.work_item_type == ::WorkItems::Type.default_by_type(:epic)
        return false unless issue.synced_epic

        issue.namespace.work_item_sync_to_epic_enabled?
      end
    end
  end
end
