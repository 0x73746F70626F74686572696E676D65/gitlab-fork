# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ElasticIndexEmbeddingBulkCronWorker, feature_category: :global_search do
  let(:worker) { described_class.new }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe '#perform' do
    it 'calls super' do
      expect(Gitlab::CurrentSettings).to receive(:elasticsearch_indexing?)

      worker.perform
    end

    context 'if embeddings are throttled' do
      before do
        allow(worker).to receive(:embeddings_throttled?).and_return(true)
      end

      it 'does not call super' do
        expect(Gitlab::CurrentSettings).not_to receive(:elasticsearch_indexing?)

        worker.perform
      end
    end

    describe 'requeuing' do
      let(:shard_number) { 2 }

      before do
        stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_requeue_workers: true)
        allow(Search::ClusterHealthCheck::Elastic).to receive(:healthy?).and_return(true)

        allow_next_instance_of(::Elastic::ProcessBookkeepingService) do |service|
          allow(service).to receive(:execute).and_return([1, 0])
        end
      end

      it 'requeues the worker' do
        expect(described_class).to receive(:perform_in).with(described_class::RESCHEDULE_INTERVAL, shard_number)

        worker.perform(shard_number)
      end

      context 'when the flag is disabled' do
        before do
          stub_feature_flags(embedding_cron_worker_re_enqueue: false)
        end

        it 'does not requeue the worker' do
          expect(described_class).not_to receive(:perform_in).with(described_class::RESCHEDULE_INTERVAL, shard_number)

          worker.perform(shard_number)
        end
      end
    end
  end
end
