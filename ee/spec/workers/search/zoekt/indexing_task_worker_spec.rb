# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexingTaskWorker, feature_category: :global_search do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform' do
    subject(:perform_worker) { described_class.new.perform(*job_args) }

    let_it_be(:project) { create(:project) }
    let_it_be(:job_args) { [project.id, 'index_repo', { 'node_id' => 1, 'force' => false, 'delay' => 3 }] }

    context 'when license zoekt_code_search is not available' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it_behaves_like 'an idempotent worker' do
        it 'does not call the IndexingTaskService service' do
          expect(Search::Zoekt::IndexingTaskService).not_to receive(:execute)
          perform_worker
        end
      end
    end

    it_behaves_like 'an idempotent worker' do
      it 'calls the IndexingTaskService service' do
        expect(Search::Zoekt::IndexingTaskService).to receive(:execute)
          .with(project.id, 'index_repo', node_id: 1, force: false, delay: 3)
        perform_worker
      end
    end
  end
end
