# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::CallbackService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node) }
  let(:service) { described_class.new(node, params) }

  describe '.execute' do
    let(:params) { {} }

    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(node, params).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(node, params)
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:params) do
      {
        'name' => task_type,
        'success' => success,
        'payload' => { 'task_id' => task_id },
        'additional_payload' => { 'repo_stats' => { index_file_count: 1, size_in_bytes: 582790 } }
      }
    end

    context 'when task is not found' do
      let(:task_id) { non_existing_record_id }
      let(:task_type) { 'index' }
      let(:success) { true }

      it 'does not performs anything' do
        expect(execute).to be nil
      end
    end

    context 'for successful operation' do
      let_it_be_with_reload(:index_zoekt_task) { create(:zoekt_task, node: node) }
      let(:success) { true }

      context 'when task is already done' do
        let(:task_type) { 'index' }
        let(:task_id) { index_zoekt_task.id }

        before do
          index_zoekt_task.done!
        end

        it 'does not update the zoekt_repository indexed_at' do
          expect { execute }.not_to change { index_zoekt_task.reload.zoekt_repository.indexed_at }
        end
      end

      context 'when the task type is index' do
        let(:task_type) { 'index' }
        let(:task_id) { index_zoekt_task.id }

        it 'updates the task state, zoekt_repository state and indexed_at' do
          freeze_time do
            expect { execute }.to change { index_zoekt_task.reload.state }.to('done')
              .and change { index_zoekt_task.zoekt_repository.indexed_at }.to(Time.current)
                .and change { index_zoekt_task.zoekt_repository.state }.to('ready')
          end
        end
      end

      context 'when the task type is delete' do
        let(:task_type) { 'delete' }
        let_it_be_with_reload(:delete_zoekt_task) { create(:zoekt_task, task_type: :delete_repo, node: node) }
        let(:task_id) { delete_zoekt_task.id }

        it 'deletes the zoekt_repository' do
          expect { execute }.to change { delete_zoekt_task.reload.state }.to('done')
          expect(delete_zoekt_task.zoekt_repository).to be nil
        end

        context 'when repository is already deleted' do
          before do
            delete_zoekt_task.zoekt_repository.destroy!
          end

          it 'moves the task to done' do
            expect { execute }.to change { delete_zoekt_task.reload.state }.to('done')
          end
        end
      end
    end

    context 'for non-successful operation' do
      let(:task_type) { 'delete' }
      let(:task_id) { zoekt_task.id }
      let(:success) { false }

      context 'when retries left' do
        let(:zoekt_task) { create(:zoekt_task, node: node) }

        it 'does not updates the task state' do
          expect { execute }.to change { zoekt_task.reload.retries_left }.by(-1).and not_change { zoekt_task.state }
        end
      end

      context 'when no retries left' do
        let(:zoekt_task) { create(:zoekt_task, node: node, retries_left: 1) }

        it 'updates the task state to failed' do
          expect { execute }.to change { zoekt_task.reload.retries_left }.from(1).to(0)
            .and change { zoekt_task.state }.to('failed')
        end
      end
    end
  end
end
