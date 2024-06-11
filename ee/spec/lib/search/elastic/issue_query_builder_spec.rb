# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::IssueQueryBuilder, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user) }
  let(:base_options) do
    {
      current_user: user,
      project_ids: project_ids,
      group_ids: [],
      public_and_internal_projects: false
    }
  end

  let(:query) { 'foo' }
  let(:project_ids) { [] }
  let(:options) { base_options }

  subject(:build) { described_class.build(query: query, options: options) }

  it 'contains all expected filters' do
    assert_names_in_query(build, with: %w[
      issue:multi_match:or:search_terms
      issue:multi_match:and:search_terms
      issue:multi_match_phrase:search_terms
      filters:not_hidden
      filters:non_archived
      filters:non_confidential
      filters:confidential
      filters:as_author
      filters:as_assignee
      filters:project:membership:id
    ])
  end

  describe 'query' do
    context 'when query is an iid' do
      let(:query) { '#1' }

      it 'returns the expected query' do
        assert_names_in_query(build, with: %w[issue:related:iid doc:is_a:issue])
      end
    end

    context 'when query is text' do
      it 'returns the expected query' do
        assert_names_in_query(build,
          with: %w[issue:multi_match:or:search_terms
            issue:multi_match:and:search_terms
            issue:multi_match_phrase:search_terms],
          without: %w[issue:match:search_terms])
      end

      context 'when advanced query syntax is used' do
        let(:query) { 'foo -default' }

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[issue:match:search_terms],
            without: %w[issue:multi_match:or:search_terms
              issue:multi_match:and:search_terms
              issue:multi_match_phrase:search_terms])
        end
      end

      context 'when search_uses_match_queries is false' do
        before do
          stub_feature_flags(search_uses_match_queries: false)
        end

        it 'returns the expected query' do
          assert_names_in_query(build,
            with: %w[issue:match:search_terms],
            without: %w[issue:multi_match:or:search_terms
              issue:multi_match:and:search_terms
              issue:multi_match_phrase:search_terms])
        end
      end
    end
  end

  describe 'filters' do
    let_it_be(:private_project) { create(:project, :private) }
    let_it_be(:authorized_project) { create(:project, developers: [user]) }
    let(:project_ids) { [authorized_project.id, private_project.id] }

    describe 'authorization' do
      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:project:membership:id])
      end
    end

    describe 'confidentiality' do
      context 'when user has appropriate role' do
        it 'applies all confidential filters' do
          assert_names_in_query(build,
            with: %w[
              filters:non_confidential
              filters:confidential
              filters:as_author
              filters:as_assignee
              filters:project:membership:id
            ])
        end

        context 'for all projects in the query' do
          let(:project_ids) { [authorized_project.id] }

          it 'does not apply the confidential filters' do
            assert_names_in_query(build, without: %w[
              filters:confidential
              filters:non_confidential
              filters:as_author
              filters:as_assignee
              filters:project:membership:id
            ])
          end
        end
      end

      context 'when user does not have role' do
        let(:project_ids) { [private_project.id] }

        it 'applies all confidential filters' do
          assert_names_in_query(build, with: %w[
            filters:non_confidential
            filters:confidential
            filters:as_author
            filters:as_assignee
            filters:project:membership:id
          ])
        end
      end

      context 'when there is no user' do
        let(:user) { nil }
        let(:project_ids) { [private_project.id] }

        it 'only applies the non-confidential filter' do
          assert_names_in_query(build, with: %w[filters:non_confidential],
            without: %w[
              filters:confidential
              filters:as_author
              filters:as_assignee
              filters:project:membership:id
            ])
        end
      end
    end

    describe 'state' do
      it 'does not apply state filters' do
        assert_names_in_query(build, without: %w[filters:state])
      end

      context 'when state option is provided' do
        let(:options) { base_options.merge(state: 'opened') }

        it 'applies state filters' do
          assert_names_in_query(build, with: %w[filters:state])
        end
      end
    end

    describe 'hidden' do
      context 'when user can admin all resources' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it 'does not apply hidden filters' do
          assert_names_in_query(build, without: %w[filters:not_hidden])
        end
      end

      it 'applies hidden filters' do
        assert_names_in_query(build, with: %w[filters:not_hidden])
      end
    end

    describe 'archived' do
      context 'when include_archived is set' do
        let(:options) { base_options.merge(include_archived: true) }

        it 'does not apply non-archived filter' do
          assert_names_in_query(build, without: %w[filters:non_archived])
        end
      end

      it 'applies non archived filters' do
        assert_names_in_query(build, with: %w[filters:non_archived])
      end
    end

    describe 'labels' do
      it 'does not include labels filter by default' do
        assert_names_in_query(build, without: %w[filters:label_ids])
      end

      context 'when labels option is provided' do
        let(:options) { base_options.merge(labels: [1]) }

        it 'applies label filters' do
          assert_names_in_query(build, with: %w[filters:label_ids])
        end
      end
    end
  end

  describe 'formats' do
    describe 'source_fields' do
      it 'applies the source field' do
        expect(build).to include(_source: ['id'])
      end
    end

    describe 'size' do
      it 'does not apply size by default' do
        expect(build).not_to include(size: 0)
      end

      context 'when count_only is set in options' do
        let(:options) { base_options.merge(count_only: true) }

        it 'does applies size' do
          expect(build).to include(size: 0)
        end
      end
    end
  end

  describe 'sort' do
    it 'does not sort by default' do
      expect(build).to include(sort: {})
    end

    context 'when sort option is provided' do
      let(:options) { base_options.merge(order_by: 'created_at', sort: 'asc') }

      it 'applies the sort' do
        expect(build).to include(sort: { created_at: { order: 'asc' } })
      end
    end
  end
end
