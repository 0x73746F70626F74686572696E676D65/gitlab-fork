# frozen_string_literal: true

module ComplianceManagement
  class PendingStatusCheckWorker
    include ApplicationWorker

    version 1
    feature_category :compliance_management
    data_consistency :delayed
    urgency :high
    idempotent!

    def perform(merge_request_id, project_id, diff_head_sha)
      merge_request = MergeRequest.find(merge_request_id)
      project = Project.find(project_id)
      status_checks = project.external_status_checks

      status_checks.each_batch do |relation|
        relation.each do |status_check|
          create_pending_status_check_response!(merge_request, status_check, diff_head_sha)
        end
      end
    end

    def create_pending_status_check_response!(merge_request, status_check, diff_head_sha)
      merge_request.status_check_responses.create!(
        external_status_check: status_check,
        sha: diff_head_sha,
        status: 'pending'
      )
    rescue ActiveRecord::RecordNotUnique
      # assume record is already associated
    end
  end
end
