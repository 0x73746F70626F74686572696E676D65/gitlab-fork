# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncOpenedMergeRequestsService < BaseMergeRequestsService
      include Gitlab::Utils::StrongMemoize

      def initialize(project:, policy_configuration:)
        super(project: project)

        @policy_configuration = policy_configuration
      end

      def execute
        each_open_merge_request do |merge_request|
          merge_request.sync_project_approval_rules_for_policy_configuration(@policy_configuration.id)

          sync_any_merge_request_approval_rules(merge_request)
          sync_preexisting_state_approval_rules(merge_request)
          notify_for_policy_violations(merge_request)

          head_pipeline = merge_request.diff_head_pipeline
          unless head_pipeline
            next ::Security::ScanResultPolicies::UnblockFailOpenApprovalRulesWorker.perform_async(merge_request.id)
          end

          ::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker.perform_async(head_pipeline.id)
          ::Ci::SyncReportsToReportApprovalRulesWorker.perform_async(head_pipeline.id)
        end
      end

      private

      def sync_any_merge_request_approval_rules(merge_request)
        return unless merge_request.approval_rules.any_merge_request.any?

        ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(merge_request.id)
      end

      def sync_preexisting_state_approval_rules(merge_request)
        return unless merge_request.approval_rules.by_report_types([:scan_finding, :license_scanning]).any?

        ::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker.perform_async(merge_request.id)
      end

      def notify_for_policy_violations(merge_request)
        ::Security::UnenforceablePolicyRulesNotificationWorker.perform_async(
          merge_request.id,
          { 'force_without_approval_rules' => true }
        )
      end
    end
  end
end
