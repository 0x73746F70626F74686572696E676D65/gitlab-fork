# frozen_string_literal: true

module Security
  module ScanResultPolicy
    extend ActiveSupport::Concern

    RULES_LIMIT = 5
    # Maximum limit that can be set via ApplicationSetting
    POLICIES_LIMIT = 20

    APPROVERS_LIMIT = 300

    SCAN_FINDING = 'scan_finding'
    LICENSE_SCANNING = 'license_scanning'
    LICENSE_FINDING = 'license_finding'
    ANY_MERGE_REQUEST = 'any_merge_request'
    SCAN_RESULT_POLICY_TYPES = %i[scan_result_policy approval_policy].freeze

    REQUIRE_APPROVAL = 'require_approval'
    SEND_BOT_MESSAGE = 'send_bot_message'

    ALLOWED_ROLES = %w[developer maintainer owner].freeze

    included do
      has_many :scan_result_policy_reads,
        class_name: 'Security::ScanResultPolicyRead',
        foreign_key: 'security_orchestration_policy_configuration_id',
        inverse_of: :security_orchestration_policy_configuration
      has_many :approval_merge_request_rules,
        foreign_key: 'security_orchestration_policy_configuration_id',
        inverse_of: :security_orchestration_policy_configuration
      has_many :approval_project_rules,
        foreign_key: 'security_orchestration_policy_configuration_id',
        inverse_of: :security_orchestration_policy_configuration

      def delete_scan_result_policy_reads
        delete_in_batches(scan_result_policy_reads)
      end

      def delete_scan_result_policy_reads_for_project(project_id)
        scan_result_policy_reads.where(project_id: project_id).delete_all
      end

      def delete_scan_finding_rules
        delete_in_batches(approval_project_rules)
        delete_in_batches(approval_merge_request_rules.for_unmerged_merge_requests)
      end

      def delete_scan_finding_rules_for_project(project_id)
        delete_in_batches(approval_project_rules.where(project_id: project_id))
        delete_in_batches(approval_merge_request_rules
                            .for_unmerged_merge_requests
                            .for_merge_request_project(project_id))
      end

      def delete_software_license_policies
        Security::ScanResultPolicyRead
          .where(security_orchestration_policy_configuration_id: id)
          .each_batch(order_hint: :updated_at) do |batch|
          delete_in_batches(SoftwareLicensePolicy.where(scan_result_policy_id: batch.select(:id)))
        end
      end

      def delete_software_license_policies_for_project(project)
        delete_in_batches(
          project
            .software_license_policies
            .where(scan_result_policy_read: scan_result_policy_reads.for_project(project))
        )
      end

      def delete_policy_violations
        Security::ScanResultPolicyRead
          .where(security_orchestration_policy_configuration_id: id)
          .each_batch(order_hint: :updated_at) do |batch|
          delete_in_batches(Security::ScanResultPolicyViolation.where(scan_result_policy_id: batch.select(:id)))
        end
      end

      def delete_policy_violations_for_project(project)
        # scan_result_policy_violations does not store security_orchestration_policy_configuration_id
        # so we need to scope them through scan_resul_policy_reads in order to delete through policy_configuration
        delete_in_batches(
          Security::ScanResultPolicyViolation
            .where(scan_result_policy_read: scan_result_policy_reads.for_project(project))
        )
      end

      def active_scan_result_policies
        scan_result_policies&.select { |config| config[:enabled] }&.first(approval_policies_limit)
      end

      def approval_policies_limit
        Gitlab::CurrentSettings.security_approval_policies_limit
      end

      def applicable_scan_result_policies_for_project(project)
        strong_memoize_with(:applicable_scan_result_policies_for_project, project) do
          policy_scope_service = ::Security::SecurityOrchestrationPolicies::PolicyScopeService.new(project: project)
          active_scan_result_policies.select { |policy| policy_scope_service.policy_applicable?(policy) }
        end
      end

      def scan_result_policies
        SCAN_RESULT_POLICY_TYPES.flat_map do |type|
          policy_by_type(type).map do |policy|
            policy.tap { |p| p[:type] = type.to_s }
          end
        end
      end

      def delete_in_batches(relation)
        relation.each_batch(order_hint: :updated_at) do |batch|
          delete_batch(batch)
        end
      end

      def delete_batch(batch)
        batch.delete_all
      end
    end
  end
end
