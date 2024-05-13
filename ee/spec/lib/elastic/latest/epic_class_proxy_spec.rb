# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::EpicClassProxy, feature_category: :global_search do
  subject { described_class.new(Epic, use_separate_indices: true) }

  let(:query) { 'test' }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:public_group) { create(:group, :public) }

  let(:elastic_search) { subject.elastic_search(query, options: options) }
  let(:response) do
    Elasticsearch::Model::Response::Response.new(Epic, Elasticsearch::Model::Searching::SearchRequest.new(Epic, '*'))
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_licensed_features(epics: true)
    stub_feature_flags(search_uses_match_queries: false)
  end

  describe '#elastic_search' do
    context 'for anonymous user' do
      let(:options) do
        {
          current_user: nil,
          public_and_internal_projects: false,
          order_by: nil,
          search_scope: 'global',
          sort: nil,
          group_ids: [],
          count_only: false
        }
      end

      it 'performs anonymous global search and returns correct results' do
        query_hash = hash_including(
          query: {
            bool: {
              filter: [
                { term: { type: hash_including(value: 'epic') } }
              ],
              must: [
                { simple_query_string: hash_including(fields: ['title^2', 'description'], query: query) }
              ],
              minimum_should_match: 1,
              should: [
                bool: { filter: [
                  { term: { visibility_level: hash_including(value: ::Gitlab::VisibilityLevel::PUBLIC) } },
                  { term: { confidential: hash_including(value: false) } }
                ] }
              ]
            }
          }
        )
        expect(subject).to receive(:search).with(query_hash, anything).and_return(response)
        expect(elastic_search).to eq(response)
      end
    end

    context 'when we give an invalid scope in options' do
      let(:options) do
        {
          public_and_internal_projects: false,
          order_by: nil,
          sort: nil,
          count_only: false
        }
      end

      it 'call match none query' do
        expect(subject).to receive(:search).with({ query: { match_none: {} }, size: 0 }, anything).and_return(response)
        expect(elastic_search).to eq(response)
      end
    end

    context 'when the user is authorized to view the group' do
      let(:options) do
        {
          current_user: user,
          public_and_internal_projects: false,
          order_by: nil,
          sort: nil,
          group_ids: [group.id],
          count_only: false,
          search_scope: 'group'
        }
      end

      before_all do
        group.add_developer(user)
      end

      it 'calls group search with the correct arguments' do
        query_hash = hash_including(
          query: {
            bool: {
              filter: [
                { term: { type: hash_including(value: 'epic') } },
                { bool: { should: [{ prefix: { traversal_ids: hash_including(value: "#{group.id}-") } }] } }
              ],
              must: [
                { simple_query_string: hash_including(fields: ['title^2', 'description'], query: query) }
              ],
              minimum_should_match: 1,
              should: [
                { bool: { filter: [
                  { term: { visibility_level: hash_including(value: ::Gitlab::VisibilityLevel::PUBLIC) } },
                  { term: { confidential: hash_including(value: false, _name: "confidential:false") } }
                ] } },
                { bool: { filter: [
                  { terms: { group_id: [group.id] } },
                  { term: { visibility_level: hash_including(value: ::Gitlab::VisibilityLevel::PRIVATE) } },
                  { term: { confidential: hash_including(value: false, _name: "confidential:false") } }
                ] } },
                { bool: { filter: [
                  { term: { visibility_level: hash_including(value: ::Gitlab::VisibilityLevel::INTERNAL) } },
                  { term: { confidential: hash_including(value: false, _name: "confidential:false") } }
                ] } },
                { bool: { filter: [
                  { term: { confidential: hash_including(value: true, _name: "confidential:true") } },
                  { terms: { group_id: [group.id], _name: "groups:can:read_confidential_epics" } }
                ] } }
              ]
            }
          }
        )

        expect(subject).to receive(:search).with(query_hash, anything).and_return(response)

        expect(elastic_search).to eq(response)
      end
    end
  end
end
