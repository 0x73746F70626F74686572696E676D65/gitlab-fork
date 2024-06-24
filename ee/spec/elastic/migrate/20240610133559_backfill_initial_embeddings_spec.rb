# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240610133559_backfill_initial_embeddings.rb')

RSpec.describe BackfillInitialEmbeddings, feature_category: :global_search do
  include DuoChatFixtureHelpers

  let(:version) { 20240610133559 }
  let(:migration) { described_class.new(version) }
  let(:klass) { objects.first.class }
  let_it_be(:embedding) { vertex_embedding_fixture }
  let_it_be(:project) { create(:project, :public) }
  let(:objects) { create_list(:issue, 3, project: project) }
  let(:expected_fields) do
    {
      embedding_version: 0,
      embedding: vertex_embedding_fixture,
      routing: 'project_1'
    }
  end

  let(:expected_throttle_delay) { 1.minute }
  let(:expected_batch_size) { 200 }

  before do
    skip 'vectors are not supported' unless Gitlab::Elastic::Helper.default.vectors_supported?(:elasticsearch)

    allow_next_instance_of(Gitlab::Llm::VertexAi::Embeddings::Text) do |instance|
      allow(instance).to receive(:execute).and_return(embedding)
    end

    stub_const('BackfillInitialEmbeddings::PROJECT_IDS', [project.id])
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
  end

  describe 'skip_migration?' do
    before do
      allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(available)
      described_class.skip_if -> { !Gitlab::Saas.feature_available?(:ai_vertex_embeddings) }
    end

    context 'if feature is available' do
      let(:available) { true }

      it 'returns false' do
        expect(migration.skip_migration?).to be_falsey
      end
    end

    context 'if feature is not available' do
      let(:available) { false }

      it 'returns true' do
        expect(migration.skip_migration?).to be_truthy
      end
    end
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(expected_throttle_delay)
      expect(migration.batch_size).to eq(expected_batch_size)
    end
  end

  describe 'migration process', :elastic_delete_by_query do
    before do
      set_elasticsearch_migration_to(version, including: false)

      # ensure objects are indexed
      objects
      ensure_elasticsearch_index!
    end

    describe '.migrate' do
      subject(:migrate) { migration.migrate }

      context 'when migration is already completed' do
        it 'does not modify data' do
          expect(Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track!)

          migrate
        end
      end

      describe 'migration process' do
        before do
          remove_field_from_objects(objects)
        end

        it 'updates all documents' do
          # track calls are batched in groups of 100
          expect(Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track!)
            .once.and_call_original do |*tracked_refs|
            expect(tracked_refs.count).to eq(3)
          end

          migrate

          ensure_elasticsearch_index!

          expect(migration.completed?).to be_truthy
        end

        it 'only updates documents missing a field', :aggregate_failures do
          object = objects.first
          add_field_for_objects(objects[1..])

          expect(Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track!)
            .once.and_call_original do |*tracked_refs|
            expect(tracked_refs.count).to eq(1)
            expect(tracked_refs.first.identifier).to eq(object.id)
          end

          migrate

          ensure_elasticsearch_index!

          expect(migration.completed?).to be_truthy
        end

        it 'processes in batches', :aggregate_failures do
          allow(migration).to receive(:batch_size).and_return(2)
          allow(migration).to receive(:update_batch_size).and_return(1)

          expect(Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track!)
            .exactly(3).times.and_call_original

          # cannot use subject in spec because it is memoized
          migration.migrate

          ensure_elasticsearch_index!

          migration.migrate

          ensure_elasticsearch_index!

          expect(migration.completed?).to be_truthy
        end
      end
    end

    describe '.completed?' do
      context 'when documents are missing field' do
        before do
          remove_field_from_objects(objects)
        end

        specify { expect(migration).not_to be_completed }
      end

      context 'when no documents are missing field' do
        specify { expect(migration).to be_completed }
      end
    end
  end

  def add_field_for_objects(objects)
    source_script = expected_fields.map do |field_name, _|
      "ctx._source['#{field_name}'] = params.#{field_name};"
    end.join

    script =  {
      source: source_script,
      lang: "painless",
      params: expected_fields
    }

    update_by_query(objects, script)
  end

  def remove_field_from_objects(objects)
    source_script = expected_fields.map do |field_name, _|
      "ctx._source.remove('#{field_name}');"
    end.join

    script = {
      source: source_script
    }

    update_by_query(objects, script)
  end

  def update_by_query(objects, script)
    object_ids = objects.map(&:id)

    client = Issue.__elasticsearch__.client
    client.update_by_query({
      index: Issue.__elasticsearch__.index_name,
      wait_for_completion: true, # run synchronously
      refresh: true, # make operation visible to search
      body: {
        script: script,
        query: {
          bool: {
            must: [
              {
                terms: {
                  id: object_ids
                }
              }
            ]
          }
        }
      }
    })
  end
end
