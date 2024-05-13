# frozen_string_literal: true

require 'spec_helper'
RSpec.describe 'Match Queries', feature_category: :global_search do
  subject { Elastic::Latest::ProjectClassProxy.new(Project) }

  let(:options) { {} }
  let(:elastic_search) { subject.elastic_search(query, options: options) }
  let(:request) { Elasticsearch::Model::Searching::SearchRequest.new(Project, '*') }
  let(:response) do
    Elasticsearch::Model::Response::Response.new(Project, request)
  end

  describe 'when feature flag is turned on' do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      stub_feature_flags(search_uses_match_queries: true)
    end

    describe 'when we do not use advanced query syntax', :elastic_delete_by_query do
      let(:query) { 'blob' }

      it 'has the multi_match named queries' do
        elastic_search.response

        assert_named_queries(
          'doc:is_a:project',
          'project:multi_match_phrase:search_terms',
          'project:multi_match:or:search_terms',
          'project:multi_match:and:search_terms'
        )
      end
    end

    describe 'when use advanced query syntax', :elastic_delete_by_query do
      let(:query) { '*' }

      it 'does not have the multi_match named queries' do
        elastic_search.response

        assert_named_queries('doc:is_a:project', without: [
          'project:multi_match_phrase:search_terms',
          'project:multi_match:or:search_terms',
          'project:multi_match:and:search_terms'
        ])
      end
    end
  end

  describe 'when feature flag is turned off' do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      stub_feature_flags(search_uses_match_queries: false)
    end

    describe 'when we do not use advanced query syntax', :elastic_delete_by_query do
      let(:query) { 'blob' }

      it 'does not have the multi_match named queries' do
        elastic_search.response

        assert_named_queries('doc:is_a:project', without: [
          'project:multi_match_phrase:search_terms',
          'project:multi_match:or:search_terms',
          'project:multi_match:and:search_terms'
        ])
      end
    end

    describe 'when use advanced query syntax', :elastic_delete_by_query do
      let(:query) { '*' }

      it 'does not have the multi_match named queries' do
        elastic_search.response

        assert_named_queries('doc:is_a:project', without: [
          'project:multi_match_phrase:search_terms',
          'project:multi_match:or:search_terms',
          'project:multi_match:and:search_terms'
        ])
      end
    end
  end
end
