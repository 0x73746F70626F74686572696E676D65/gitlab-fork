# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateWorkflowService, feature_category: :duo_workflow do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let(:params) { {} }

    subject(:execute) do
      described_class
        .new(project: project, current_user: user, params: params)
        .execute
    end

    it 'creates a new workflow' do
      expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
      expect(execute[:workflow]).to be_a(Ai::DuoWorkflows::Workflow)
      expect(execute[:workflow].user).to eq(user)
      expect(execute[:workflow].project).to eq(project)
    end

    context 'when the workflow cannot be saved' do
      before do
        allow_next_instance_of(Ai::DuoWorkflows::Workflow) do |instance|
          allow(instance).to receive(:save).and_return(false)
          instance.errors.add(:base, "Something bad")
        end
      end

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to include('Something bad')
      end
    end
  end
end
