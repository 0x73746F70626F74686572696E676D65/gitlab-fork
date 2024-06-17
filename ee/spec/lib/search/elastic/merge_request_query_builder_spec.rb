# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MergeRequestQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      public_and_internal_projects: true
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      merge_request:multi_match:or:search_terms
      merge_request:multi_match:and:search_terms
      merge_request:multi_match_phrase:search_terms
      filters:not_hidden
      filters:non_archived
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '!1' }

      it 'returns the expected query' do
        assert_names_in_query(build, with: %w[merge_request:related:iid doc:is_a:merge_request])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[merge_request:multi_match:or:search_terms
            merge_request:multi_match:and:search_terms
            merge_request:multi_match_phrase:search_terms],
          without: %w[merge_request:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build, with: %w[merge_request:match:search_terms])
        end
      end

      context 'when search_uses_match_queries is false' do
        before do
          stub_feature_flags(search_uses_match_queries: false)
        end

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[merge_request:match:search_terms],
            without: %w[merge_request:multi_match:or:search_terms
              merge_request:multi_match:and:search_terms
              merge_request:multi_match_phrase:search_terms])
        end
      end
    end
  end

  describe 'filters' do
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    it_behaves_like 'a query filtered by archived'
    it_behaves_like 'a query filtered by hidden'
    it_behaves_like 'a query filtered by state'

    describe 'authorization' do
      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:project:membership:id])
      end
    end
  end

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for count_only'
  end
end
