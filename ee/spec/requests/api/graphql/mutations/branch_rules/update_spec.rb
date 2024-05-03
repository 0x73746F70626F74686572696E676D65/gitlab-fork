# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BranchRuleUpdate', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:protected_branch, reload: true) do
    create(:protected_branch, project: project, default_merge_level: false, default_push_level: false)
  end

  let!(:code_owner_approval_required) { !protected_branch.code_owner_approval_required }
  let!(:allow_force_push) { !protected_branch.allow_force_push }

  let(:current_user) { user }
  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:global_id) { branch_rule.to_global_id }
  let(:name) { 'new_name' }
  let(:merge_access_levels) { [{ access_level: 0 }] }
  let(:push_access_levels) { [{ access_level: 0 }] }
  let(:mutation) { graphql_mutation(:branch_rule_update, params) }
  let(:mutation_response) { graphql_mutation_response(:branch_rule_update) }
  let(:params) do
    {
      id: global_id,
      name: name,
      branch_protection: {
        code_owner_approval_required: code_owner_approval_required,
        allow_force_push: allow_force_push,
        merge_access_levels: merge_access_levels,
        push_access_levels: push_access_levels
      }
    }
  end

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: user) }

  context 'when the user can update a branch rules' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(code_owner_approval_required: true)
    end

    it 'updates the branch rule' do
      post_mutation

      expect(protected_branch.reload.name).to eq(name)
      expect(protected_branch.code_owner_approval_required).to eq(code_owner_approval_required)
      expect(protected_branch.allow_force_push).to eq(allow_force_push)

      merge_access_level = an_object_having_attributes(**merge_access_levels.first)
      expect(protected_branch.merge_access_levels).to contain_exactly(merge_access_level)

      push_access_level = an_object_having_attributes(**push_access_levels.first)
      expect(protected_branch.push_access_levels).to contain_exactly(push_access_level)
    end
  end

  context 'with blocking scan result policy' do
    let(:branch_name) { branch_rule.name }
    let(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    include_context 'with scan result policy blocking protected branches'

    before do
      create(:scan_result_policy_read, :blocking_protected_branches, project: project,
        security_orchestration_policy_configuration: policy_configuration)
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: ["Internal server error: Gitlab::Access::AccessDeniedError"]
  end
end
