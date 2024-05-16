# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Zoekt::IndexerWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be(:project) { create(:project, :repository) }
  let(:use_zoekt) { true }

  subject(:worker) { described_class.new }

  before do
    # Mocking Project.find simplifies the stubs on project.use_zoekt? and
    # project.repository
    allow(Project).to receive(:find_by_id).with(project.id).and_return(project)
    allow(project).to receive(:use_zoekt?).and_return(use_zoekt)
    stub_feature_flags(zoekt_random_force_reindexing: false)
  end

  describe '#perform' do
    it 'sends the project to Zoekt for indexing' do
      expect(project.repository).to receive(:update_zoekt_index!)

      worker.perform(project.id)
    end

    it 'sends the project to Zoekt for indexing when force: true is set' do
      expect(project.repository).to receive(:update_zoekt_index!).with(force: true)

      options = { "force" => true }
      worker.perform(project.id, options)
    end

    context 'when application_setting zoekt_indexing_enabled is disabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_enabled: false)
      end

      it 'does not send the project to Zoekt for indexing' do
        expect(project.repository).not_to receive(:update_zoekt_index!)

        worker.perform(project.id)
      end
    end

    context 'when the zoekt_code_search licensed feature is disabled' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it 'does nothing' do
        expect(project.repository).not_to receive(:update_zoekt_index!)

        worker.perform(project.id)
      end
    end

    context 'when the project does not have zoekt enabled' do
      let(:use_zoekt) { false }

      it 'does not send the project to Zoekt for indexing' do
        expect(project.repository).not_to receive(:update_zoekt_index!)

        worker.perform(project.id)
      end
    end

    context 'when project is not found' do
      before do
        allow(Project).to receive(:find_by_id).with(project.id).and_return(nil)
      end

      it 'returns false' do
        expect(worker.perform(project.id)).to eq(false)
      end
    end

    context 'with random force reindexing' do
      before do
        stub_feature_flags(zoekt_random_force_reindexing: true)
        stub_const("#{described_class}::REINDEXING_CHANCE_PERCENTAGE", 100)
      end

      it 'sends the project to Zoekt for indexing with force: true' do
        expect(project.repository).to receive(:update_zoekt_index!).with(force: true)

        worker.perform(project.id)
      end
    end

    context 'when the indexer is locked for the given project' do
      let(:options) { { "force" => true } }

      it 'skips index and schedules a job' do
        expect(worker).to receive(:in_lock)
          .with(
            "Zoekt::IndexerWorker/#{project.id}",
            ttl: (Zoekt::IndexerWorker::TIMEOUT + 1.minute),
            retries: 0)
          .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

        expect(project.repository).not_to receive(:update_zoekt_index!)
        expect(described_class).to receive(:perform_in)
          .with(Zoekt::IndexerWorker::RETRY_IN_IF_LOCKED, project.id, options)

        worker.perform(project.id, options)
      end
    end

    context 'when index fails with 429 Too many requests' do
      let(:options) { { "force" => true } }

      it 'skips index and schedules a job' do
        expect(project.repository).to receive(:update_zoekt_index!)
          .and_raise(Gitlab::Search::Zoekt::Client::TooManyRequestsError)
        expect(described_class).to receive(:perform_in)
          .with(a_value_between(0,
            Zoekt::IndexerWorker::RETRY_IN_PERIOD_IF_TOO_MANY_REQUESTS), project.id, options)

        worker.perform(project.id, options)
      end
    end

    context 'when the project has no repository' do
      let(:project) { create(:project) }

      it 'does nothing' do
        expect(project.repository).not_to receive(:update_zoekt_index!)

        worker.perform(project.id)
      end
    end

    context 'when the project has an empty repository' do
      let(:project) { create(:project_empty_repo) }

      it 'does nothing' do
        expect(project.repository).not_to receive(:update_zoekt_index!)

        worker.perform(project.id)
      end
    end
  end
end
