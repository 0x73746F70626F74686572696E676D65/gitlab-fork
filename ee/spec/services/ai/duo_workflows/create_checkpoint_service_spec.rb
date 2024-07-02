# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateCheckpointService, feature_category: :duo_workflow do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let(:workflow) { create(:duo_workflows_workflow, project: project) }
    let(:thread_ts) { Time.current.to_s }
    let(:parent_ts) { (Time.current - 1.second).to_s }
    let(:metadata) { { another_key: 'another value' } }
    let(:params) { { thread_ts: thread_ts, parent_ts: parent_ts, checkpoint: { key: 'value' }, metadata: metadata } }

    subject(:execute) do
      described_class
        .new(project: project, workflow: workflow, params: params)
        .execute
    end

    it 'creates a new checkpoint' do
      expect { execute }.to change { workflow.reload.checkpoints.count }.by(1)
      expect(execute[:checkpoint]).to be_a(Ai::DuoWorkflows::Checkpoint)
      expect(execute[:checkpoint].workflow).to eq(workflow)
      expect(execute[:checkpoint].project).to eq(project)
      expect(execute[:checkpoint].thread_ts).to eq(thread_ts)
      expect(execute[:checkpoint].parent_ts).to eq(parent_ts)
      expect(execute[:checkpoint].checkpoint).to eq({ 'key' => 'value' })
      expect(execute[:checkpoint].metadata).to eq({ 'another_key' => 'another value' })
    end

    context 'when there is invalid params' do
      let(:thread_ts) { '' }

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message].to_s).to include("can't be blank")
      end
    end
  end
end
