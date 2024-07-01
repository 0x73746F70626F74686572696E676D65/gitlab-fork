# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Queries, feature_category: :global_search do
  describe '#by_iid' do
    subject(:by_iid) { described_class.by_iid(iid: 1, doc_type: 'my_type') }

    it 'returns the expected query hash' do
      expected_filter = [
        { term: { iid: { _name: 'my_type:related:iid', value: 1 } } },
        { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
      ]

      expect(by_iid[:query][:bool][:must]).to eq([])
      expect(by_iid[:query][:bool][:must_not]).to eq([])
      expect(by_iid[:query][:bool][:should]).to eq([])
      expect(by_iid[:query][:bool][:filter]).to eq(expected_filter)
    end
  end

  describe '#by_simple_query_string' do
    let(:query) { 'foo bar' }
    let(:options) { base_options }
    let(:base_options) { { doc_type: 'my_type' } }
    let(:fields) { %w[iid^3 title^2 description] }

    subject(:by_simple_query_string) do
      described_class.by_simple_query_string(fields: fields, query: query, options: options)
    end

    context 'when custom elasticsearch analyzers are enabled' do
      before do
        stub_ee_application_setting(elasticsearch_analyzers_smartcn_enabled: true,
          elasticsearch_analyzers_smartcn_search: true)
      end

      it 'applies custom analyzer fields' do
        expected_must = [
          { simple_query_string: { _name: 'my_type:match:search_terms',
                                   fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                                   query: 'foo bar', lenient: true, default_operator: :and } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eql(expected_must)
      end
    end

    it 'applies highlight in query' do
      expected = { fields: { iid: {}, title: {}, description: {} },
                   number_of_fragments: 0, pre_tags: ['gitlabelasticsearch→'], post_tags: ['←gitlabelasticsearch'] }

      expect(by_simple_query_string[:highlight]).to eq(expected)
    end

    context 'when query is provided' do
      it 'returns a simple_query_string query as a must and adds doc type as a filter' do
        expected_must = [
          { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid^3 title^2 description],
                                   query: 'foo bar', lenient: true, default_operator: :and } }
        ]
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eq(expected_must)
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq([])
        expect(by_simple_query_string[:query][:bool][:filter]).to eq(expected_filter)
      end
    end

    context 'when query is not provided' do
      let(:query) { nil }

      it 'returns a match_all query' do
        expected_must = { match_all: {} }

        expect(by_simple_query_string[:query][:bool][:must]).to eq(expected_must)
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq([])
        expect(by_simple_query_string[:query][:bool][:filter]).to eq([])
        expect(by_simple_query_string[:track_scores]).to eq(true)
      end
    end

    context 'when options[:count_only] is true' do
      let(:options) { base_options.merge(count_only: true) }

      it 'does not apply highlight in query' do
        expect(by_simple_query_string[:highlight]).to be_nil
      end

      it 'removes field boosts and returns a simple_query_string as a filter' do
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } },
          { simple_query_string: { _name: 'my_type:match:search_terms', fields: %w[iid title description],
                                   query: 'foo bar', lenient: true, default_operator: :and } }
        ]

        expect(by_simple_query_string[:query][:bool][:must]).to eq([])
        expect(by_simple_query_string[:query][:bool][:must_not]).to eq([])
        expect(by_simple_query_string[:query][:bool][:should]).to eq([])
        expect(by_simple_query_string[:query][:bool][:filter]).to eq(expected_filter)
      end
    end
  end

  describe '#by_multi_match_query' do
    let(:query) { 'foo bar' }
    let(:options) { base_options }
    let(:base_options) { { doc_type: 'my_type' } }
    let(:fields) { %w[iid^3 title^2 description] }

    subject(:by_multi_match_query) do
      described_class.by_multi_match_query(fields: fields, query: query, options: options)
    end

    context 'when custom elasticsearch analyzers are enabled' do
      before do
        stub_ee_application_setting(elasticsearch_analyzers_smartcn_enabled: true,
          elasticsearch_analyzers_smartcn_search: true)
      end

      it 'applies custom analyzer fields to multi_match_query' do
        expected_must = [{ bool: {
          should: [
            { multi_match: { _name: 'my_type:multi_match:or:search_terms',
                             fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                             query: 'foo bar', operator: :or, lenient: true } },
            { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                             fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                             query: 'foo bar', operator: :and, lenient: true } },
            { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                             type: :phrase, fields: %w[iid^3 title^2 description title.smartcn description.smartcn],
                             query: 'foo bar', lenient: true } }
          ],
          minimum_should_match: 1
        } }]

        expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
      end
    end

    it 'applies highlight in query' do
      expected = { fields: { iid: {}, title: {}, description: {} },
                   number_of_fragments: 0, pre_tags: ['gitlabelasticsearch→'], post_tags: ['←gitlabelasticsearch'] }

      expect(by_multi_match_query[:highlight]).to eq(expected)
    end

    context 'when query is provided' do
      it 'returns a by_multi_match_query query as a should and adds doc type as a filter' do
        expected_must = [{ bool: {
          should: [
            { multi_match: { _name: 'my_type:multi_match:or:search_terms',
                             fields: %w[iid^3 title^2 description],
                             query: 'foo bar', operator: :or, lenient: true } },
            { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                             fields: %w[iid^3 title^2 description],
                             query: 'foo bar', operator: :and, lenient: true } },
            { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                             type: :phrase, fields: %w[iid^3 title^2 description],
                             query: 'foo bar', lenient: true } }
          ],
          minimum_should_match: 1
        } }]

        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } }
        ]

        expect(by_multi_match_query[:query][:bool][:must]).to eql(expected_must)
        expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
        expect(by_multi_match_query[:query][:bool][:should]).to eq([])
        expect(by_multi_match_query[:query][:bool][:filter]).to eq(expected_filter)
      end
    end

    context 'when query is not provided' do
      let(:query) { nil }

      it 'returns a match_all query' do
        expected_must = { match_all: {} }

        expect(by_multi_match_query[:query][:bool][:must]).to eq(expected_must)
        expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
        expect(by_multi_match_query[:query][:bool][:should]).to eq([])
        expect(by_multi_match_query[:query][:bool][:filter]).to eq([])
        expect(by_multi_match_query[:track_scores]).to eq(true)
      end
    end

    context 'when options[:count_only] is true' do
      let(:options) { base_options.merge(count_only: true) }

      it 'does not apply highlight in query' do
        expect(by_multi_match_query[:highlight]).to be_nil
      end

      it 'removes field boosts and returns a by_multi_match_query as a filter' do
        expected_filter = [
          { term: { type: { _name: 'doc:is_a:my_type', value: 'my_type' } } },
          { bool: {
            should: [
              { multi_match: { _name: 'my_type:multi_match:or:search_terms',
                               fields: %w[iid title description],
                               query: 'foo bar', operator: :or, lenient: true } },
              { multi_match: { _name: 'my_type:multi_match:and:search_terms',
                               fields: %w[iid title description],
                               query: 'foo bar', operator: :and, lenient: true } },
              { multi_match: { _name: 'my_type:multi_match_phrase:search_terms',
                               type: :phrase, fields: %w[iid title description],
                               query: 'foo bar', lenient: true } }
            ],
            minimum_should_match: 1
          } }
        ]

        expect(by_multi_match_query[:query][:bool][:must]).to eq([])
        expect(by_multi_match_query[:query][:bool][:must_not]).to eq([])
        expect(by_multi_match_query[:query][:bool][:should]).to eq([])
        expect(by_multi_match_query[:query][:bool][:filter]).to eql(expected_filter)
      end
    end
  end

  describe '#by_knn' do
    let_it_be(:user) { create(:user) }
    let(:query_hash) { { query: { bool: { filter: filter } } } }
    let(:filter) { { foo: 'bar' } }
    let(:hybrid_similarity) { 0.5 }
    let(:options) { { current_user: user, hybrid_similarity: hybrid_similarity } }
    let(:embedding_service) { instance_double(Gitlab::Llm::VertexAi::Embeddings::Text) }
    let(:mock_embedding) { [1, 2, 3] }

    subject(:by_knn) { described_class.by_knn(query_hash: query_hash, query: 'test', options: options) }

    before do
      allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:execute).and_return(mock_embedding)
    end

    it 'returns the expected query hash' do
      expect(by_knn).to have_key(:knn)
      expect(by_knn[:knn][:query_vector]).to eq(mock_embedding)
      expect(by_knn[:knn][:similarity]).to eq(hybrid_similarity)
      expect(by_knn[:knn][:filter]).to eq(filter)
    end

    context 'if the embedding endpoint is throttled' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it 'tracks the error and does not include the knn query' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)

        expect(by_knn).not_to have_key(:knn)
      end
    end

    context 'if an error is raised' do
      before do
        allow(embedding_service).to receive(:execute).and_raise(StandardError, 'error')
      end

      it 'tracks the error and does not include the knn query' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)

        expect(by_knn).not_to have_key(:knn)
      end
    end
  end
end
