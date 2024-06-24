# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UpdateApprovalsService
      include Gitlab::Utils::StrongMemoize
      include PolicyViolationCommentGenerator
      include VulnerabilityStatesHelper

      attr_reader :pipeline, :merge_request, :violations

      def initialize(merge_request:, pipeline:)
        @pipeline = pipeline
        @merge_request = merge_request
        @violations = Security::SecurityOrchestrationPolicies::UpdateViolationsService.new(merge_request, :scan_finding)
      end

      def execute
        pipeline_complete = if pipeline.include_manual_to_pipeline_completion_enabled?
                              pipeline.complete_or_manual?
                            else
                              pipeline.complete?
                            end

        return unless pipeline_complete
        return unless pipeline.can_store_security_reports?

        all_scan_finding_rules = merge_request.approval_rules.scan_finding

        approval_rules_with_newly_detected_states = all_scan_finding_rules.select do |rule|
          include_newly_detected?(rule)
        end

        return if approval_rules_with_newly_detected_states.empty?

        log_update_approval_rule('Evaluating MR approval rules from scan result policies', **validation_context)

        violated_rules, unviolated_rules = partition_rules(approval_rules_with_newly_detected_states)

        update_required_approvals(violated_rules, unviolated_rules)
        violations.add(violated_rules.pluck(:scan_result_policy_id), unviolated_rules.pluck(:scan_result_policy_id)) # rubocop:disable CodeReuse/ActiveRecord
        violations.execute
        generate_policy_bot_comment(
          merge_request,
          all_scan_finding_rules.applicable_to_branch(merge_request.target_branch),
          :scan_finding
        )
      end

      private

      def validation_context
        { pipeline_ids: related_pipeline_ids, target_pipeline_ids: related_target_pipeline_ids }
      end

      delegate :project, to: :pipeline

      def update_required_approvals(violated_rules, unviolated_rules)
        # Ensure we require approvals for violated rules
        # in case the approvals had been removed before and the pipeline has found violations after re-run
        merge_request.reset_required_approvals(violated_rules)

        ApprovalMergeRequestRule.remove_required_approved(unviolated_rules) if unviolated_rules.any?
      end

      def partition_rules(approval_rules)
        approval_rules.partition do |approval_rule|
          approval_rule = approval_rule.source_rule if approval_rule.source_rule

          if !fail_open?(approval_rule) && scan_removed?(approval_rule)
            log_update_approval_rule(
              'Updating MR approval rule',
              reason: 'Scanner removed by MR',
              approval_rule_id: approval_rule.id,
              approval_rule_name: approval_rule.name,
              missing_scans: missing_scans(approval_rule)
            )
            violations.add_error(
              approval_rule.scan_result_policy_id, :scan_removed, missing_scans: missing_scans(approval_rule)
            )
            next true
          end

          approval_rule_violated = violates_approval_rule?(approval_rule)
          if approval_rule_violated
            log_update_approval_rule(
              'Updating MR approval rule',
              reason: 'scan_finding rule violated',
              approval_rule_id: approval_rule.id,
              approval_rule_name: approval_rule.name
            )
          end

          approval_rule_violated
        end
      end

      def log_update_approval_rule(message, **attributes)
        default_attributes = {
          event: 'update_approvals',
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          project_path: project.full_path
        }
        Gitlab::AppJsonLogger.info(message: message, **default_attributes.merge(attributes))
      end

      def violates_approval_rule?(approval_rule)
        target_pipeline_uuids = target_pipeline_findings_uuids(approval_rule)
        findings_count_violated?(approval_rule, target_pipeline_uuids)
      end

      def missing_scans(approval_rule)
        scan_types_diff = target_pipeline_security_scan_types - pipeline_security_scan_types
        scanners = approval_rule.scanners

        return scan_types_diff if scanners.empty?

        scan_types_diff & scanners
      end

      def scan_removed?(approval_rule)
        missing_scans(approval_rule).any?
      end

      def pipeline_security_scan_types
        security_scan_types(related_pipeline_ids)
      end
      strong_memoize_attr :pipeline_security_scan_types

      def target_pipeline_security_scan_types
        security_scan_types(related_target_pipeline_ids)
      end
      strong_memoize_attr :target_pipeline_security_scan_types

      def target_pipeline
        merge_request.latest_scan_finding_comparison_pipeline
      end
      strong_memoize_attr :target_pipeline

      def findings_count_violated?(approval_rule, target_pipeline_uuids)
        vulnerabilities_allowed = approval_rule.vulnerabilities_allowed

        pipeline_uuids = pipeline_findings_uuids(approval_rule)
        new_uuids = pipeline_uuids - target_pipeline_uuids

        if only_newly_detected?(approval_rule)
          violated = new_uuids.count > vulnerabilities_allowed
          add_violation_data(approval_rule, newly_detected: new_uuids) if violated
          return violated
        end

        vulnerabilities_count = vulnerabilities_count_for_uuids(pipeline_uuids + target_pipeline_uuids, approval_rule)
        previously_existing_uuids = (pipeline_uuids + target_pipeline_uuids - new_uuids).uniq

        if vulnerabilities_count[:exceeded_allowed_count]
          add_violation_data(approval_rule, newly_detected: new_uuids, previously_existing: previously_existing_uuids)
          return true
        end

        total_count = vulnerabilities_count[:count]
        total_count += new_uuids.count if include_newly_detected?(approval_rule)

        violated = total_count > vulnerabilities_allowed

        if violated
          add_violation_data(approval_rule, newly_detected: new_uuids, previously_existing: previously_existing_uuids)
        end

        violated
      end

      def add_violation_data(rule, newly_detected: nil, previously_existing: nil)
        violations.add_violation(
          rule.scan_result_policy_id,
          {
            uuids: {
              newly_detected: Security::ScanResultPolicyViolation.trim_violations(newly_detected),
              previously_existing: Security::ScanResultPolicyViolation.trim_violations(previously_existing)
            }.compact_blank
          },
          context: validation_context
        )
      end

      def related_pipeline_sources
        Enums::Ci::Pipeline.ci_and_security_orchestration_sources.values
      end

      def security_scan_types(pipeline_ids)
        Security::Scan.by_pipeline_ids(pipeline_ids).distinct_scan_types
      end

      def related_target_pipeline_ids
        return [] unless target_pipeline

        Security::RelatedPipelinesFinder.new(target_pipeline, {
          sources: related_pipeline_sources,
          ref: merge_request.target_branch
        }).execute
      end
      strong_memoize_attr :related_target_pipeline_ids

      def related_pipeline_ids
        Security::RelatedPipelinesFinder.new(pipeline, { sources: related_pipeline_sources }).execute
      end
      strong_memoize_attr :related_pipeline_ids

      def target_pipeline_findings_uuids(approval_rule)
        findings_uuids(target_pipeline, approval_rule, related_target_pipeline_ids)
      end

      def pipeline_findings_uuids(approval_rule)
        findings_uuids(pipeline, approval_rule, related_pipeline_ids, true)
      end

      def findings_uuids(pipeline, approval_rule, pipeline_ids, check_dismissed = false)
        finder_params = {
          vulnerability_states: approval_rule.vulnerability_states_for_branch,
          severity_levels: approval_rule.severity_levels,
          scanners: approval_rule.scanners,
          fix_available: approval_rule.vulnerability_attribute_fix_available,
          false_positive: approval_rule.vulnerability_attribute_false_positive,
          check_dismissed: check_dismissed
        }

        finder_params[:related_pipeline_ids] = pipeline_ids if pipeline_ids.present?

        Security::ScanResultPolicies::FindingsFinder
          .new(project, pipeline, finder_params)
          .execute
          .distinct_uuids
      end

      def vulnerabilities_count_for_uuids(uuids, approval_rule)
        VulnerabilitiesCountService.new(
          project: project,
          uuids: uuids,
          states: states_without_newly_detected(approval_rule.vulnerability_states_for_branch),
          allowed_count: approval_rule.vulnerabilities_allowed,
          vulnerability_age: approval_rule.scan_result_policy_read&.vulnerability_age
        ).execute
      end

      def fail_open?(approval_rule)
        approval_rule.scan_result_policy_read&.fail_open?
      end
    end
  end
end
