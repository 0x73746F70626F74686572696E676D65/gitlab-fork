# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PolicyScopeService < BaseProjectService
      def policy_applicable?(policy)
        return false if policy.blank?

        applicable_for_compliance_framework?(policy) && applicable_for_project?(policy)
      end

      private

      def applicable_for_compliance_framework?(policy)
        policy_scope_compliance_frameworks = policy.dig(:policy_scope, :compliance_frameworks).to_a
        return true if policy_scope_compliance_frameworks.blank?

        compliance_framework_id = project.compliance_framework_settings.first&.framework_id
        return false if compliance_framework_id.nil?

        policy_scope_compliance_frameworks.any? { |framework| framework[:id] == compliance_framework_id }
      end

      def applicable_for_project?(policy)
        policy_scope_included_projects = policy.dig(:policy_scope, :projects, :including).to_a
        policy_scope_excluded_projects = policy.dig(:policy_scope, :projects, :excluding).to_a

        return false if policy_scope_excluded_projects.any? { |policy_project| policy_project[:id] == project.id }
        return true if policy_scope_included_projects.blank?

        policy_scope_included_projects.any? { |policy_project| policy_project[:id] == project.id }
      end
    end
  end
end
