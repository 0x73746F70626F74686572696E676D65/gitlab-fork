# frozen_string_literal: true

module EE
  module MergeRequests
    module UpdateService
      extend ::Gitlab::Utils::Override

      override :handle_changes
      def handle_changes(merge_request, options)
        super

        handle_override_requested_changes(merge_request, merge_request.previous_changes)
        handle_title_and_desc_edits(merge_request, merge_request.previous_changes.keys)
      end

      private

      override :general_fallback
      def general_fallback(merge_request)
        if merge_request.merged?
          params.delete(:reset_approval_rules_to_defaults)
          params.delete(:approval_rules_attributes)
        end

        reset_approval_rules(merge_request) if params.delete(:reset_approval_rules_to_defaults)

        merge_request = super(merge_request)

        merge_request.reset_approval_cache!

        return merge_request if update_task_event?

        ::MergeRequests::UpdateBlocksService
          .new(merge_request, current_user, blocking_merge_requests_params)
          .execute

        merge_request
      end

      override :after_update
      def after_update(merge_request, old_associations)
        super

        merge_request.run_after_commit do
          ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.perform_async(merge_request.id)
        end
      end

      override :delete_approvals_on_target_branch_change
      def delete_approvals_on_target_branch_change(merge_request)
        delete_approvals(merge_request) if reset_approvals?(merge_request, nil)
        sync_any_merge_request_approval_rules(merge_request)
        notify_for_policy_violations(merge_request)
      end

      def reset_approval_rules(merge_request)
        return unless merge_request.project.can_override_approvers?

        merge_request.approval_rules.regular_or_any_approver.delete_all
      end

      def sync_any_merge_request_approval_rules(merge_request)
        return unless merge_request.approval_rules.any_merge_request.any?

        ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(merge_request.id)
      end

      def notify_for_policy_violations(merge_request)
        ::Security::SyncPolicyViolationCommentWorker.perform_async(merge_request.id)
      end

      def handle_override_requested_changes(merge_request, changed_fields)
        return unless changed_fields.include?('override_requested_changes')

        override_requested_changes = changed_fields['override_requested_changes']

        ::SystemNoteService.override_requested_changes(merge_request, current_user, override_requested_changes.last)
        trigger_merge_request_status_updated(merge_request)

        return unless ::Feature.enabled?(:merge_when_checks_pass, merge_request.project)

        ::Gitlab::EventStore.publish(
          ::MergeRequests::OverrideRequestedChangesStateEvent.new(
            data: { current_user_id: current_user.id, merge_request_id: merge_request.id }
          )
        )
      end

      def handle_title_and_desc_edits(merge_request, changed_fields)
        return unless ::Feature.enabled?(:merge_when_checks_pass, merge_request.project)

        fields = %w[title description]

        return unless changed_fields.any? { |field| fields.include?(field) }

        return unless merge_request.has_jira_issue_keys?

        ::Gitlab::EventStore.publish(
          ::MergeRequests::JiraTitleDescriptionUpdateEvent.new(
            data: { current_user_id: current_user.id, merge_request_id: merge_request.id }
          )
        )
      end
    end
  end
end
