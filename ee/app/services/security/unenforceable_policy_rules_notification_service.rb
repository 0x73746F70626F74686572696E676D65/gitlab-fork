# frozen_string_literal: true

module Security
  class UnenforceablePolicyRulesNotificationService
    include Gitlab::Utils::StrongMemoize
    include ::Security::ScanResultPolicies::PolicyViolationCommentGenerator

    def initialize(merge_request)
      @merge_request = merge_request
      @pipeline = merge_request.diff_head_pipeline
    end

    def execute
      notify_for_report_type(merge_request, :scan_finding, merge_request.approval_rules.scan_finding)
      notify_for_report_type(merge_request, :license_scanning, merge_request.approval_rules.license_scanning)
    end

    private

    attr_reader :merge_request, :pipeline

    delegate :project, to: :merge_request, private: true

    def notify_for_report_type(merge_request, report_type, approval_rules)
      return unless unenforceable_report?(report_type)

      unblock_fail_open_rules(report_type)

      applicable_rules = approval_rules.applicable_to_branch(merge_request.target_branch)

      violations = Security::SecurityOrchestrationPolicies::UpdateViolationsService.new(merge_request, report_type)
      applicable_rules.each do |rule|
        next if rule.scan_result_policy_read&.fail_open?

        violations.add_error(rule.scan_result_policy_id, :artifacts_missing)
      end
      violations.execute

      generate_policy_bot_comment(merge_request, applicable_rules, report_type)
    end

    def unenforceable_report?(report_type)
      return true if pipeline.nil?

      case report_type
      when :scan_finding
        # Pipelines which can store security reports are handled via SyncFindingsToApprovalRulesService
        related_pipelines.none?(&:can_store_security_reports?)
      when :license_scanning
        # Pipelines which have scanning results available are handled via SyncLicenseScanningRulesService
        related_pipelines.none?(&:can_ingest_sbom_reports?)
      end
    end

    def related_pipelines
      related_pipelines_id = Security::RelatedPipelinesFinder.new(pipeline, {
        sources: Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values
      }).execute

      project.all_pipelines.id_in(related_pipelines_id)
    end
    strong_memoize_attr :related_pipelines

    def unblock_fail_open_rules(report_type)
      Security::ScanResultPolicies::UnblockFailOpenApprovalRulesService
        .new(merge_request: merge_request, report_types: [report_type])
        .execute
    end
  end
end
