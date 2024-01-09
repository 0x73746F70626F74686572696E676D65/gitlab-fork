# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::BranchRule, feature_category: :source_code_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }

  subject(:branch_rule) { described_class.new(project, protected_branch) }

  it 'delegates methods to protected branch' do
    expect(branch_rule).to delegate_method(:external_status_checks).to(:protected_branch)
    expect(branch_rule).to delegate_method(:can_unprotect?).to(:protected_branch)
  end

  describe '#approval_project_rules' do
    subject(:approval_project_rules) { branch_rule.approval_project_rules }

    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }

    it 'returns approval rules with deduplicated policy rules' do
      policy1_rule1 = create(:approval_project_rule, project: project, protected_branches: [protected_branch],
        security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 1)
      policy1_rule2 = create(:approval_project_rule, project: project, protected_branches: [protected_branch],
        security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 1)
      policy2_rule1 = create(:approval_project_rule, project: project, protected_branches: [protected_branch],
        security_orchestration_policy_configuration: configuration, orchestration_policy_idx: 2)
      other_rule1 = create(:approval_project_rule, project: project, protected_branches: [protected_branch])
      other_rule2 = create(:approval_project_rule, project: project, protected_branches: [protected_branch])

      expect(approval_project_rules).to include(policy1_rule1, policy2_rule1, other_rule1, other_rule2)
      expect(approval_project_rules).not_to include(policy1_rule2)
    end
  end
end
