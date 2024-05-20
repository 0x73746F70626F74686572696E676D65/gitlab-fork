# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Elastic Ingestion Pipeline', :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: user) }

  let(:project_routing) { "project_#{project.id}" }
  let(:search_service) { ::SearchService.new(user, { scope: scope, search: '*' }) }
  let(:logger) { ::Gitlab::Elasticsearch::Logger.build }
  let(:bulk_indexer) { ::Gitlab::Elastic::BulkIndexer.new(logger: logger) }
  let(:bookkeeping_service) { ::Elastic::ProcessBookkeepingService }
  let(:client) { Gitlab::Elastic::Helper.default.client }

  before do
    allow(::Gitlab::Elastic::BulkIndexer).to receive(:new).and_return(bulk_indexer)
    allow(::Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger)
    allow(::Gitlab::Elastic::Client).to receive(:build).and_return(client)
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    ensure_elasticsearch_index!
  end

  context 'for legacy references' do
    let(:scope) { 'issues' }

    it 'adds the document to the index' do
      issue = build(:issue, project: project)

      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(issue).and_call_original
      expect(::Search::Elastic::Reference).to receive(:serialize).with(issue).and_call_original
      expect(::Search::Elastic::References::Legacy).to receive(:serialize).with(issue).and_call_original
      expect(Gitlab::Elastic::DocumentReference).to receive(:serialize_record).with(issue).and_call_original

      issue.save!

      serialized_issue = "Issue #{issue.id} #{issue.id} #{project_routing}"

      expect(::Search::Elastic::Reference).to receive(:deserialize).with(serialized_issue).and_call_original
      expect(::Search::Elastic::References::Legacy).to receive(:instantiate).with(serialized_issue).and_call_original
      expect(Gitlab::Elastic::DocumentReference).to receive(:deserialize).with(serialized_issue).and_call_original

      expect(Search::Elastic::Reference).to receive(:preload_database_records).and_call_original
      expect(bulk_indexer).to receive(:process).and_call_original

      ensure_elasticsearch_index!

      expect(docs_in_index('gitlab-test-issues')).to match_array([{ id: issue.id.to_s, routing: project_routing }])
    end

    context 'when a manual reference exists in the queue' do
      it 'serializes, deserializes and indexes the reference correctly' do
        issue = create(:issue, project: project)
        serialized_issue = "Issue #{issue.id} #{issue.id} #{project_routing}"

        ensure_elasticsearch_index!

        ref = Gitlab::Elastic::DocumentReference.new(Issue, issue.id, issue.es_id, issue.es_parent)
        ::Elastic::ProcessBookkeepingService.track!(ref)
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_issue, Float])

        issue.update!(title: 'My title 2')
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_issue, Float])

        ensure_elasticsearch_index!

        expect(bookkeeping_service.queued_items).to eq({})
        expect(docs_in_index('gitlab-test-issues').last).to eq({ id: issue.id.to_s, routing: project_routing })
      end
    end

    context 'when a string reference exists in the queue' do
      it 'serializes, deserializes and indexes the reference correctly' do
        issue = create(:issue, project: project)
        serialized_issue = "Issue #{issue.id} #{issue.id} #{project_routing}"

        ensure_elasticsearch_index!

        ref = Gitlab::Elastic::DocumentReference.new(Issue, issue.id, issue.es_id, issue.es_parent).serialize
        ::Elastic::ProcessBookkeepingService.track!(ref)
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_issue, Float])

        issue.update!(title: 'My title 2')
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_issue, Float])

        ensure_elasticsearch_index!

        expect(bookkeeping_service.queued_items).to eq({})
        expect(docs_in_index('gitlab-test-issues').last).to eq({ id: issue.id.to_s, routing: project_routing })
      end
    end

    context 'if a manually created ref fails to be deserialized' do
      it 'bookkeeping does not fail' do
        ::Elastic::ProcessBookkeepingService.track!('1')

        expect(logger).to receive(:error).with(hash_including('message' => 'submit_document_failed'))

        expect { ensure_elasticsearch_index! }.not_to raise_error
      end
    end

    context 'if a ref fails to be indexed' do
      it 'bookkeeping does not fail' do
        issue = create(:issue, project: project)
        serialized_issue = "Issue #{issue.id} #{issue.id} #{project_routing}"

        allow(client).to receive(:bulk).and_raise(StandardError)

        expect { ensure_elasticsearch_index! }.not_to raise_error

        expect(docs_in_index('gitlab-test-issues')).to be_empty
        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_issue, Float])

        ensure_elasticsearch_index!

        expect(bookkeeping_service.queued_items.values.flatten).to match_array([serialized_issue, Float])
      end
    end
  end

  def docs_in_index(index)
    client
      .search(index: index)
      .dig('hits', 'hits')
      .map { |hit| { id: hit['_id'], routing: hit['_routing'] } }
  end
end
