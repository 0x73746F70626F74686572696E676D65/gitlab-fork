# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UpdateLicenseApprovalsService
      include Gitlab::Utils::StrongMemoize
      include ::Security::ScanResultPolicies::PolicyViolationCommentGenerator

      def initialize(merge_request, pipeline, preexisting_states = false)
        @merge_request = merge_request
        @pipeline = pipeline
        @preexisting_states = preexisting_states
      end

      def execute
        return if merge_request.merged?

        all_license_approval_rules = merge_request
                           .approval_rules
                           .report_approver
                           .license_scanning
                           .with_scan_result_policy_read
                           .including_scan_result_policy_read

        return if all_license_approval_rules.empty?
        return if !preexisting_states && !scanner.results_available?

        filtered_rules = filter_approval_rules(all_license_approval_rules)
        return if filtered_rules.empty?

        update_approvals(filtered_rules)

        generate_policy_bot_comment(
          merge_request,
          all_license_approval_rules.applicable_to_branch(merge_request.target_branch),
          :license_scanning
        )
      end

      private

      attr_reader :merge_request, :pipeline, :preexisting_states

      delegate :project, to: :merge_request

      def filter_approval_rules(approval_rules)
        rule_filter = ->(approval_rule) { approval_rule.scan_result_policy_read.newly_detected? }

        preexisting_states ? approval_rules.reject(&rule_filter) : approval_rules.select(&rule_filter)
      end

      def update_approvals(license_approval_rules)
        violated_rules, unviolated_rules = license_approval_rules.partition do |approval_rule|
          partition_rule(approval_rule)
        end

        merge_request.reset_required_approvals(violated_rules)
        ApprovalMergeRequestRule.remove_required_approved(unviolated_rules)

        # rubocop:disable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit -- pluck on already loaded records
        violations.add(
          violated_rules.pluck(:scan_result_policy_id), unviolated_rules.pluck(:scan_result_policy_id)
        )
        # rubocop:enable CodeReuse/ActiveRecord, Database/AvoidUsingPluckWithoutLimit
        violations.execute

        violated_rules.each do |approval_rule|
          log_update_approval_rule(approval_rule_id: approval_rule.id, approval_rule_name: approval_rule.name)
        end
      end

      def partition_rule(rule)
        scan_result_policy_read = rule.scan_result_policy_read
        return false if !target_branch_pipeline && fail_open?(scan_result_policy_read)

        denied_licenses_with_dependencies = violation_checker.execute(scan_result_policy_read)

        if denied_licenses_with_dependencies.present?
          add_violation_data(rule, denied_licenses_with_dependencies)
          return true
        end

        false
      end

      def violation_checker
        report = scanner.report
        target_branch_report = ::Gitlab::LicenseScanning.scanner_for_pipeline(project, target_branch_pipeline).report

        Security::ScanResultPolicies::LicenseViolationChecker.new(
          project, report, target_branch_report
        )
      end

      def scanner
        ::Gitlab::LicenseScanning.scanner_for_pipeline(project, pipeline)
      end
      strong_memoize_attr :scanner

      def violations
        Security::SecurityOrchestrationPolicies::UpdateViolationsService.new(merge_request, :license_scanning)
      end
      strong_memoize_attr :violations

      def target_branch_pipeline
        merge_request.latest_comparison_pipeline_with_sbom_reports
      end
      strong_memoize_attr :target_branch_pipeline

      def validation_context
        { pipeline_ids: [pipeline&.id].compact, target_pipeline_ids: [target_branch_pipeline&.id].compact }
      end

      def log_update_approval_rule(**attributes)
        default_attributes = {
          reason: 'license_finding rule violated',
          event: 'update_approvals',
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          project_path: project.full_path
        }

        Gitlab::AppJsonLogger.info(
          message: 'Updating MR approval rule',
          **default_attributes.merge(attributes).merge(validation_context)
        )
      end

      def add_violation_data(rule, denied_licenses_with_dependencies)
        return if denied_licenses_with_dependencies.blank?

        trimmed_license_list = denied_licenses_with_dependencies
                                              .first(Security::ScanResultPolicyViolation::MAX_VIOLATIONS)
                                              .to_h
                                              .transform_values do |dependencies|
          Security::ScanResultPolicyViolation.trim_violations(dependencies)
        end
        violations.add_violation(rule.scan_result_policy_id, trimmed_license_list, context: validation_context)
      end

      def fail_open?(scan_result_policy_read)
        scan_result_policy_read&.fail_open?
      end
    end
  end
end
