# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Geo::SkipSecondary, feature_category: :global_search do
  let_it_be(:project) { create(:project, :repository) }
  let!(:worker) do
    Class.new do
      def perform(project_id)
        project = Project.find(project_id)

        Gitlab::Elastic::Indexer.new(project).run
      end

      def self.name
        'DummyIndexingWorker'
      end

      include ApplicationWorker
      prepend ::Geo::SkipSecondary
    end.new
  end

  let(:worker_args) { [project.id] }

  it 'includes all workers with feature_category :global_search' do
    exceptions = [
      PauseControl::ResumeWorker,
      ConcurrencyLimit::ResumeWorker
    ]

    expected_workers = [
      ::Elastic::NamespaceUpdateWorker,
      ::Elastic::ProjectTransferWorker,
      ::Elastic::MigrationWorker,

      ElasticAssociationIndexerWorker,
      ElasticCommitIndexerWorker,
      ElasticDeleteProjectWorker,
      ElasticFullIndexWorker,
      ElasticNamespaceIndexerWorker,
      ElasticRemoveExpiredNamespaceSubscriptionsFromIndexCronWorker,
      ElasticWikiIndexerWorker,
      ElasticIndexBulkCronWorker,
      ElasticIndexInitialBulkCronWorker,
      ElasticNamespaceRolloutWorker,
      ElasticClusterReindexingCronWorker,
      ElasticIndexingControlWorker,

      Search::ElasticDefaultBranchChangedWorker,
      Search::ElasticGroupAssociationDeletionWorker,
      Search::IndexCurationWorker,
      Search::NamespaceIndexIntegrityWorker,
      Search::ProjectIndexIntegrityWorker,
      Search::Wiki::ElasticDeleteGroupWikiWorker,
      Search::Elastic::TriggerIndexingWorker,

      Search::Zoekt::DefaultBranchChangedWorker,
      Zoekt::IndexerWorker,
      Search::Zoekt::DeleteProjectWorker,
      Search::Zoekt::SchedulingWorker,
      Search::Zoekt::ProjectTransferWorker,
      Search::Zoekt::NamespaceIndexerWorker,
      Search::Zoekt::IndexingTaskWorker
    ]

    workers = ObjectSpace.each_object(::Class).select do |klass|
      klass < ApplicationWorker &&
        klass.get_feature_category == :global_search &&
        exceptions.exclude?(klass)
    end

    expect(workers.uniq).to match_array(expected_workers)
  end

  context 'when ::Gitlab::Geo.secondary? is true' do
    before do
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(true)
    end

    it 'returns nil' do
      expect(worker).to receive(:geo_logger).once.and_call_original
      expect(Gitlab::Geo::Logger).to receive(:info).once.and_call_original
      expect(worker.perform(*worker_args)).to be(nil)
    end
  end
end
