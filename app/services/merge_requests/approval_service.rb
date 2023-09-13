# frozen_string_literal: true

module MergeRequests
  class ApprovalService < MergeRequests::BaseService
    def execute(merge_request)
      return unless eligible_for_approval?(merge_request)

      approval = merge_request.approvals.new(
        user: current_user,
        patch_id_sha: fetch_patch_id_sha(merge_request)
      )

      return success unless save_approval(approval)

      reset_approvals_cache(merge_request)

      merge_request_activity_counter.track_approve_mr_action(user: current_user, merge_request: merge_request)

      trigger_merge_request_merge_status_updated(merge_request)
      trigger_merge_request_reviewers_updated(merge_request)
      trigger_merge_request_approval_state_updated(merge_request)

      # Approval side effects (things not required to be done immediately but
      # should happen after a successful approval) should be done asynchronously
      # utilizing the `Gitlab::EventStore`.
      #
      # Workers can subscribe to the `MergeRequests::ApprovedEvent`.
      Gitlab::EventStore.publish(
        MergeRequests::ApprovedEvent.new(
          data: { current_user_id: current_user.id, merge_request_id: merge_request.id }
        )
      )

      success
    end

    private

    def fetch_patch_id_sha(merge_request)
      diff_refs = merge_request.diff_refs
      base_sha = diff_refs&.base_sha
      head_sha = diff_refs&.head_sha

      return unless base_sha && head_sha
      return if base_sha == head_sha

      merge_request.project.repository.get_patch_id(base_sha, head_sha)
    end

    def eligible_for_approval?(merge_request)
      merge_request.eligible_for_approval_by?(current_user)
    end

    def save_approval(approval)
      Approval.safe_ensure_unique do
        approval.save
      end
    end

    def reset_approvals_cache(merge_request)
      merge_request.approvals.reset
    end
  end
end

MergeRequests::ApprovalService.prepend_mod_with('MergeRequests::ApprovalService')
