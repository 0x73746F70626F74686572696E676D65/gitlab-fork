# frozen_string_literal: true

module EE
  module Projects
    module TransferService
      extend ::Gitlab::Utils::Override

      private

      override :execute_system_hooks
      def execute_system_hooks
        super

        Audit::ProjectChangesAuditor.new(current_user, project).execute
      end

      override :transfer_missing_group_resources
      def transfer_missing_group_resources(group)
        super

        ::Epics::TransferService.new(current_user, group, project).execute
      end

      override :post_update_hooks
      def post_update_hooks(project, old_group)
        super

        ::Elastic::ProjectTransferWorker.perform_async(project.id, old_namespace.id, new_namespace.id)
        ::Search::Zoekt::ProjectTransferWorker.perform_async(project.id, old_namespace.id)

        delete_scan_result_policies(old_group)
        unassign_policy_project
        sync_new_group_policies
        delete_compliance_framework_setting
        schedule_vulnerability_reads_update
        update_compliance_standards_adherence
      end

      override :remove_paid_features
      def remove_paid_features
        ::EE::Projects::RemovePaidFeaturesService.new(project).execute(new_namespace)
      end

      def unassign_policy_project
        return unless project.security_orchestration_policy_configuration

        ::Security::Orchestration::UnassignService.new(container: project, current_user: current_user).execute
      end

      def delete_scan_result_policies(old_group)
        project.all_security_orchestration_policy_configurations.each do |configuration|
          configuration.delete_scan_finding_rules_for_project(project.id)
        end
        return unless old_group

        old_group.all_security_orchestration_policy_configurations.each do |configuration|
          configuration.delete_scan_finding_rules_for_project(project.id)
        end
      end

      def sync_new_group_policies
        ::Security::ScanResultPolicies::SyncProjectWorker.perform_async(project.id)
      end

      def delete_compliance_framework_setting
        project.compliance_framework_setting&.delete
      end

      def schedule_vulnerability_reads_update
        return if ::Feature.enabled?(:update_vuln_reads_traversal_ids_via_event, project, type: :gitlab_com_derisk)
        return unless project.project_setting&.has_vulnerabilities?

        Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker.perform_async(project.id)
      end

      def update_compliance_standards_adherence
        project.compliance_standards_adherence.update_all(namespace_id: new_namespace.id)
      end
    end
  end
end
