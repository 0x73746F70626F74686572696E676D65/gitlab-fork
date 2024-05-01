# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchRules::ExternalStatusChecks::DestroyService, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { Projects::BranchRule.new(project, protected_branch) }
  let(:action_allowed) { true }
  let(:external_status_check) do
    create(:external_status_check, project: project, protected_branches: [protected_branch])
  end

  let(:params) { { id: external_status_check.id } }

  subject(:execute) { described_class.new(branch_rule, user, params).execute }

  before do
    allow(Ability).to receive(:allowed?)
                        .with(user, :update_branch_rule, branch_rule)
                        .and_return(action_allowed)

    stub_licensed_features(audit_events: true)
  end

  context 'when the service execution succeeds', :request_store do
    specify '#success? is true' do
      expect(execute.success?).to be(true)
    end

    it 'destroys the external_status_check record' do
      execute

      expect { external_status_check.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'does not include errors in payload' do
      response = execute

      expect(response.errors).to be_empty
    end
  end

  shared_examples 'with invalid branch rules' do |message|
    it 'responds with the expected errors' do
      expect(execute.error?).to be true
      expect { execute }.not_to change { external_status_check }
      expect(execute.message).to eq(message)
    end
  end

  context 'when the service execution fails' do
    context 'when id parameter is missing' do
      let(:params) { { branch_rule_id: branch_rule.id } }

      it 'returns a service error response' do
        expect(execute.success?).to be(false)
        expect(execute.message).to eq("Couldn't find MergeRequests::ExternalStatusCheck without an ID")
        expect(execute.payload[:errors]).to contain_exactly('Not found')
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when user is not allowed to destroy an external_status_check record' do
      let(:action_allowed) { false }

      it 'returns a service error response' do
        expect(execute.error?).to be(true)
        expect(execute.message).to eq('Failed to destroy external status check')
        expect(execute.reason).to eq(:access_denied)
        expect(execute.payload[:errors]).to contain_exactly('Not allowed')
      end

      it 'does not destroy the external_status_check record' do
        expect { execute }.not_to change { external_status_check }
      end
    end

    context 'when the given branch rule is not and instance of Projects::BranchRule' do
      let(:branch_rule) { create(:protected_branch) }

      it 'returns an error' do
        expect(execute.error?).to be true
      end

      it 'does not destroy the external status check' do
        expect { execute }.not_to change { external_status_check }
      end

      it 'responds with the expected errors' do
        expect(execute.message).to eq('Unknown branch rule type.')
      end
    end

    context 'with ::Projects::AllBranchesRule' do
      let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }

      it_behaves_like 'with invalid branch rules', 'All branch rules cannot configure external status checks'
    end

    context 'with ::Projects::AllProtectedBranchesRule' do
      let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }

      it_behaves_like 'with invalid branch rules', 'All protected branch rules cannot configure external status checks'
    end
  end
end
