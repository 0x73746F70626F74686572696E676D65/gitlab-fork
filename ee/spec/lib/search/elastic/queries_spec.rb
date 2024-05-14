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

        expect(by_simple_query_string[:query][:bool][:must]).to eq(expected_must)
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

      it 'adds size set to 0 in query' do
        expect(by_simple_query_string[:size]).to eq(0)
      end

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
end
