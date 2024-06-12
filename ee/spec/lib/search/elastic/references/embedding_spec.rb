# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::Embedding, feature_category: :global_search do
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let(:routing) { "project_#{project.id}" }
  let(:embedding_ref) { described_class.new(Issue, issue.id, routing) }
  let(:embedding_ref_serialized) { "Embedding|Issue|#{issue.id}|#{routing}" }

  it 'inherits from Reference' do
    expect(described_class.ancestors).to include(Search::Elastic::Reference)
  end

  describe '.serialize' do
    it 'builds a string with model klass, identifier and routing' do
      expect(described_class.serialize(issue)).to eq(embedding_ref_serialized)
    end
  end

  describe '.ref' do
    it 'returns an instance of embedding reference when given a record' do
      ref = described_class.ref(issue)

      expect(ref).to be_an_instance_of(described_class)
      expect(ref.model_klass).to eq(Issue)
      expect(ref.identifier).to eq(issue.id)
      expect(ref.routing).to eq(routing)
    end
  end

  describe '.instantiate' do
    it 'returns an instance of embedding reference when given a serialized string' do
      ref = described_class.instantiate(embedding_ref_serialized)

      expect(ref).to be_an_instance_of(described_class)
      expect(ref.model_klass).to eq(Issue)
      expect(ref.identifier).to eq(issue.id)
      expect(ref.routing).to eq(routing)
    end
  end

  describe '.preload_indexing_data' do
    let_it_be(:project2) { create(:project) }
    let_it_be(:issue2) { create(:issue, project: project2) }
    let(:embedding_ref2) { described_class.new(Issue, issue2.id, "project_#{project2.id}") }

    it 'preloads database records to avoid N+1 queries' do
      refs = []
      refs << Search::Elastic::Reference.deserialize(embedding_ref.serialize)

      control = ActiveRecord::QueryRecorder.new { described_class.preload_indexing_data(refs).map(&:database_record) }

      refs = []
      refs <<  Search::Elastic::Reference.deserialize(embedding_ref.serialize)
      refs <<  Search::Elastic::Reference.deserialize(embedding_ref2.serialize)

      database_records = nil
      expect do
        database_records = described_class.preload_indexing_data(refs).map(&:database_record)
      end.not_to exceed_query_limit(control)

      expect(database_records[0]).to eq(issue)
      expect(database_records[1]).to eq(issue2)
    end

    it 'calls preload in batches not to overload the database' do
      stub_const('Search::Elastic::Concerns::DatabaseClassReference::BATCH_SIZE', 1)
      refs = [embedding_ref, embedding_ref2]

      expect(Issue).to receive(:preload_indexing_data).and_call_original.twice

      described_class.preload_indexing_data(refs)
    end
  end

  describe '#serialize' do
    it 'returns a delimited string' do
      expect(embedding_ref.serialize).to eq(embedding_ref_serialized)
    end
  end

  describe '#as_indexed_json' do
    let(:embedding_service) { instance_double(Gitlab::Llm::VertexAi::Embeddings::Text) }
    let(:mock_embedding) { [1, 2, 3] }

    before do
      allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:execute).and_return(mock_embedding)
    end

    it 'returns the embedding and its version' do
      expect(embedding_ref.as_indexed_json).to eq({ embedding: mock_embedding, embedding_version: 0, routing: routing })
    end

    it 'calls embedding API' do
      content = "issue with title '#{issue.title}' and description '#{issue.description}'"
      tracking_context = { action: 'issue_embedding' }

      expect(Gitlab::Llm::VertexAi::Embeddings::Text)
        .to receive(:new)
        .with(content, user: nil, tracking_context: tracking_context)
        .and_return(embedding_service)

      embedding_ref.as_indexed_json
    end

    context 'if the endpoint is throttled' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it 'raises a ReferenceFailure error' do
        message = "Failed to generate embedding: Rate limited endpoint 'vertex_embeddings_api' is throttled"
        expect { embedding_ref.as_indexed_json }.to raise_error(::Search::Elastic::Reference::ReferenceFailure, message)
      end
    end

    context 'if an error is raised' do
      before do
        allow(embedding_service).to receive(:execute).and_raise(StandardError, 'error')
      end

      it 'raises a ReferenceFailure error' do
        message = 'Failed to generate embedding: error'
        expect { embedding_ref.as_indexed_json }.to raise_error(::Search::Elastic::Reference::ReferenceFailure, message)
      end
    end
  end

  describe '#operation' do
    it 'is upsert' do
      expect(embedding_ref.operation).to eq(:upsert)
    end

    context 'when the database record does not exist' do
      before do
        allow(embedding_ref).to receive(:database_record).and_return(nil)
      end

      it 'is delete' do
        expect(embedding_ref.operation).to eq(:delete)
      end
    end
  end

  describe '#index_name' do
    it 'is equal to proxy index name' do
      expect(embedding_ref.index_name).to eq('gitlab-test-issues')
    end
  end
end
