# frozen_string_literal: true

require 'support/helpers/listbox_helpers'

module Features
  module SecurityPolicyHelpers
    private

    def create_security_policy
      merge_policy_mr(create_policy_update_branch)
    end

    def create_policy_setup
      stub_feature_flags(merge_when_checks_pass: false)
      stub_feature_flags(bulk_create_scan_result_policies: false)
      stub_feature_flags(custom_software_license: false)
      stub_licensed_features(security_dashboard: true,
        multiple_approval_rules: true,
        sast: true, report_approver_rules: true,
        security_orchestration_policies: true)
      policy_management_project.add_developer(user)

      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)

      create_security_policy
    end

    def create_policy_update_branch
      params = { policy_yaml: policy_yaml, name: policy_name, operation: :append }
      service = Security::SecurityOrchestrationPolicies::PolicyCommitService.new(container: project,
        current_user: user,
        params: params)
      response = service.execute

      response[:branch]
    end

    def policy_yaml
      policy_hash.merge(type: 'scan_result_policy').to_yaml
    end

    def policy_hash
      build(:scan_result_policy, name: policy_name,
        actions: [{ type: 'require_approval', approvals_required: 1,
                    role_approvers: approver_roles }], rules: [policy_rule])
    end

    def license_type
      'MIT'
    end

    def policy_rule
      {
        type: 'license_finding',
        branches: policy_branch_names,
        match_on_inclusion_license: true,
        license_types: [license_type],
        license_states: license_states
      }
    end

    def merge_policy_mr(policy_update_branch_name)
      mr_params = merge_request_params(policy_update_branch_name)

      policy_merge_request = ::MergeRequests::CreateService.new(project: policy_management_project,
        current_user: user,
        params: mr_params).execute

      merge_params = merge_params(policy_merge_request)

      policy_merge_request.merge_async(user.id, merge_params)
    end

    def merge_params(policy_merge_request)
      {
        commit_message: 'Merge commit message',
        squash_commit_message: 'Squash commit message',
        sha: policy_merge_request.diff_head_sha
      }
    end

    def merge_request_params(policy_update_branch_name)
      {
        title: 'Add policy file',
        target_branch: policy_management_project.default_branch,
        source_branch: policy_update_branch_name
      }
    end
  end
end
