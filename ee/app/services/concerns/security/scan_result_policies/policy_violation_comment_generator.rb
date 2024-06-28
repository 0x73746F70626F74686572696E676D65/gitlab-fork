# frozen_string_literal: true

module Security
  module ScanResultPolicies
    module PolicyViolationCommentGenerator
      private

      def generate_policy_bot_comment(merge_request, approval_rules, report_type)
        return if bot_message_disabled?(merge_request)
        return unless violations_populated?(merge_request)

        Security::GeneratePolicyViolationCommentWorker.perform_async(
          merge_request.id,
          { 'report_type' => Security::ScanResultPolicies::PolicyViolationComment::REPORT_TYPES[report_type],
            'violated_policy' => violations_exist?(merge_request, approval_rules),
            'requires_approval' => rules_requiring_approval?(approval_rules) }
        )
      end

      def violations_populated?(merge_request)
        return true if ::Feature.disabled?(:save_policy_violation_data, merge_request.project)

        !merge_request.scan_result_policy_violations.without_violation_data.exists?
      end

      def violations_exist?(merge_request, approval_rules)
        scope = merge_request.scan_result_policy_violations.for_approval_rules(approval_rules)
        scope = scope.with_violation_data if ::Feature.enabled?(:save_policy_violation_data, merge_request.project)
        scope.exists?
      end

      def rules_requiring_approval?(approval_rules)
        approval_rules.any? { |rule| rule.approvals_required > 0 }
      end

      def bot_message_disabled?(merge_request)
        project = merge_request.project
        return false if Feature.disabled?(:approval_policy_disable_bot_comment, project) &&
          Feature.disabled?(:approval_policy_disable_bot_comment_group, project.group)

        security_policy_ids = merge_request.approval_rules.report_approver
                                           .applicable_to_branch(merge_request.target_branch)
                                           .filter_map(&:scan_result_policy_id)
        return false if security_policy_ids.blank?

        policies = project.scan_result_policy_reads.id_in(security_policy_ids)
        return false if policies.blank?

        policies.all?(&:bot_message_disabled?)
      end
    end
  end
end
