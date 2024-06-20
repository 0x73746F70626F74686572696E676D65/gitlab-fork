# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::UpdateService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:params) { { name: 'test' } }

  describe '#execute' do
    subject(:execute) { described_class.new(branch_rule, user, params).execute }

    before do
      allow(Ability).to receive(:allowed?).and_return(true)
      stub_licensed_features(code_owner_approval_required: true)
    end

    context 'when branch rule is a Projects::BranchRule' do
      let_it_be(:code_owner_approval_required) { true }
      let_it_be(:developer) { create(:user, developer_of: project) }
      let_it_be(:developers_group) { create(:project_group_link, project: project).group }
      let_it_be(:protected_branch, reload: true) do
        create(
          :protected_branch,
          project: project,
          code_owner_approval_required: !code_owner_approval_required,
          default_merge_level: false,
          default_push_level: false
        )
      end

      let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
      let(:push_access_levels) { [{ user_id: developer.id }, { group_id: developers_group.id }] }
      let(:merge_access_levels) { [{ user_id: developer.id }, { group_id: developers_group.id }] }
      let(:params) do
        {
          branch_protection: {
            code_owner_approval_required: code_owner_approval_required,
            push_access_levels: push_access_levels,
            merge_access_levels: merge_access_levels
          }
        }
      end

      it 'accepts params for EE only settings', :aggregate_failures do
        expect(execute).to be_success
        expect(protected_branch.code_owner_approval_required).to eq(code_owner_approval_required)
        expect(protected_branch.merge_access_levels.count).to eq(2)
        expect(protected_branch.merge_access_levels.first.user_id).to eq(developer.id)
        expect(protected_branch.merge_access_levels.second.group_id).to eq(developers_group.id)
        expect(protected_branch.push_access_levels.count).to eq(2)
        expect(protected_branch.push_access_levels.first.user_id).to eq(developer.id)
        expect(protected_branch.push_access_levels.second.group_id).to eq(developers_group.id)
      end

      context 'when code_owner_approval_required is null' do
        let(:code_owner_approval_required) { nil }

        # TODO: We should be validating
        # ProtectedBranch#code_owner_approval_required is not null instead of
        # relying on db constraints
        it 'raises a not null violation error' do
          expect { execute }.to raise_error(ActiveRecord::NotNullViolation)
        end
      end

      context 'when invalid access_levels are passed' do
        let(:push_access_levels) { [{ user_id: 0 }, { group_id: 0 }] }
        let(:merge_access_levels) { [{ user_id: 0 }, { group_id: 0 }] }

        it 'returns an error response' do
          response = execute
          expect(response).to be_error
          expect(response[:message]).to match_array([
            "Merge access levels user can't be blank",
            "Merge access levels group can't be blank",
            "Push access levels user can't be blank",
            "Push access levels group can't be blank"
          ])
        end
      end
    end

    context 'when branch_rule is a Projects::AllBranchesRule' do
      let(:branch_rule) { Projects::AllBranchesRule.new(project) }

      it 'returns an error response' do
        response = execute
        expect(response).to be_error
        expect(response[:message]).to eq('All branches rules cannot be updated.')
      end
    end

    context 'when branch_rule is a Projects::AllProtectedBranchesRule' do
      let(:branch_rule) { Projects::AllProtectedBranchesRule.new(project) }

      it 'returns an error response' do
        response = execute
        expect(response).to be_error
        expect(response[:message]).to eq('All protected branches rules cannot be updated.')
      end
    end
  end
end
