# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240213091440_reindex_projects_to_apply_routing.rb')

RSpec.describe ReindexProjectsToApplyRouting, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20240213091440 }
  let(:migration) { described_class.new(version) }
  let(:client) { ::Gitlab::Search::Client.new }
  let_it_be(:group) { create(:group) }
  let(:routing) { "n_#{group.id}" }
  let(:expected_throttle_delay) { 1.minute }
  let(:expected_batch_size) { 9000 }
  let(:klass) { Project }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    set_elasticsearch_migration_to(version, including: false)

    allow(migration).to receive(:client).and_return(client)
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(expected_throttle_delay)
      expect(migration.batch_size).to eq(expected_batch_size)
    end
  end

  describe '.migrate' do
    subject(:migrate) { migration.migrate }

    context 'when migration is already completed' do
      it 'does not modify data' do
        expect(::Elastic::ProcessInitialBookkeepingService).not_to receive(:track!)

        expect(routing_for_projects).to all(eq(routing))

        migrate
      end
    end

    describe 'migration process' do
      context 'when an error is raised' do
        before do
          create_and_index_projects!(stub_all: true)

          allow(migration).to receive(:process_batch!).and_raise(StandardError, 'E')
          allow(migration).to receive(:log).and_return(true)
        end

        it 'logs a message' do
          expect(migration).to receive(:log_raise).with('migrate failed', error_class: StandardError, error_mesage: 'E')
          migrate
        end
      end

      context 'when all documents need to be updated' do
        it 'updates all documents' do
          create_and_index_projects!(stub_all: true)

          # track calls are batched in groups of 100
          expect(::Elastic::ProcessInitialBookkeepingService)
            .to receive(:track!).once.and_call_original do |*tracked_refs|
              expect(tracked_refs.count).to eq(3)
            end

          expect(client).to receive(:delete_by_query).and_call_original.once

          migrate

          ensure_elasticsearch_index!

          expect(routing_for_projects).to all(eq(routing))
          expect(migration.completed?).to be_truthy
        end
      end

      context 'when some documents needs to be updated' do
        it 'only updates documents where routing is missing', :aggregate_failures do
          create_and_index_projects!(stub_first: true)
          expect(routing_for_projects).to match_array([nil, routing, routing])

          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).once.and_call_original
          expect(client).to receive(:delete_by_query).and_call_original.once

          allow_next_instance_of(Project) do |project|
            allow(project).to receive(:es_parent).and_call_original
          end

          migrate
          ensure_elasticsearch_index!

          expect(routing_for_projects).to all(eq(routing))
          expect(migration.completed?).to be_truthy
        end
      end

      it 'processes in batches', :aggregate_failures do
        create_and_index_projects!(stub_all: true)

        allow(migration).to receive(:batch_size).and_return(2)
        stub_const('ReindexProjectsToApplyRouting::UPDATE_BATCH_SIZE', 1)

        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).exactly(3).times.and_call_original

        # cannot use subject in spec because it is memoized
        migration.migrate

        ensure_elasticsearch_index!

        migration.migrate

        ensure_elasticsearch_index!

        expect(routing_for_projects).to all(eq(routing))
        expect(migration.completed?).to be_truthy
      end
    end
  end

  describe '.completed?' do
    context 'when some documents do not have routing' do
      it 'is not completed' do
        create_and_index_projects!(stub_all: true)

        expect(migration).not_to be_completed
      end
    end

    context 'when all documents have routing' do
      it 'is completed' do
        create_and_index_projects!

        expect(migration).to be_completed
      end
    end
  end

  context 'when delete_by_query fails' do
    it 'logs an error but does not fail' do
      allow(client).to receive(:delete_by_query).and_return('failures' => 'failed')

      create_and_index_projects!(stub_all: true)

      expect(migration).to receive(:log_raise).with('Failed to delete Project', { failures: 'failed' })

      expect { migration.migrate }.not_to raise_error
    end
  end

  describe 'es_parent' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    it 'is equal to the project root namespace id' do
      expect(migration.es_parent(project.id)).to eq("n_#{group.id}")
    end

    context 'if the project does not exist' do
      it 'schedules a deletion worker' do
        expect(ElasticDeleteProjectWorker).to receive(:perform_async).with(non_existing_record_id, anything)

        expect(migration.es_parent(non_existing_record_id)).to be_nil
      end
    end
  end

  def create_and_index_projects!(stub_first: false, stub_all: false)
    objects = build_list(:project, 3, group: group)

    objects.each_with_index do |object, index|
      allow(object).to receive(:es_parent).and_return(nil) if stub_all || (stub_first && index == 0)

      object.save!
    end

    ensure_elasticsearch_index!
  end

  def routing_for_projects
    client
      .search(index: Project.__elasticsearch__.index_name)
      .dig('hits', 'hits')
      .pluck('_routing')
  end
end
