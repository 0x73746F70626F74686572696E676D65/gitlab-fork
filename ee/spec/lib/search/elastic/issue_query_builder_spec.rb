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

    describe 'hybrid search' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:project) { create(:project) }
      let(:project_ids) { [project.id] }
      let(:embedding_service) { instance_double(Gitlab::Llm::VertexAi::Embeddings::Text) }
      let(:mock_embedding) { [1, 2, 3] }
      let(:hybrid_similarity) { 0.5 }
      let(:options) { base_options.merge(hybrid_similarity: hybrid_similarity) }

      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
        allow(user).to receive(:any_group_with_ai_available?).and_return(true)
        allow(Gitlab::Llm::VertexAi::Embeddings::Text).to receive(:new).and_return(embedding_service)
        allow(embedding_service).to receive(:execute).and_return(mock_embedding)
        allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
          .with(:add_embedding_to_issues).and_return(true)
      end

      shared_examples 'without hybrid search query' do
        it 'does not add a knn query' do
          expect(build).not_to have_key(:knn)
        end
      end

      it 'adds a knn query with the same filters as the bool filters' do
        query = build

        expect(query).to have_key(:knn)
        expect(query[:knn][:query_vector]).to eq(mock_embedding)
        expect(query[:knn][:similarity]).to eq(hybrid_similarity)

        expected_filters = %w[
          filters:project
          filters:non_confidential
          filters:confidential
          filters:as_author
          filters:as_assignee
          filters:project:membership:id
        ]

        knn_filter = query[:knn][:filter]
        query_without_knn = query.except(:knn)

        assert_names_in_query(knn_filter, with: expected_filters)
        assert_names_in_query(query_without_knn, with: expected_filters)
      end

      context 'if project_ids is not specified' do
        let(:project_ids) { [] }

        it_behaves_like 'without hybrid search query'
      end

      context 'if use is not authorized to perform ai actions' do
        before do
          allow(user).to receive(:any_group_with_ai_available?).and_return(false)
        end

        it_behaves_like 'without hybrid search query'
      end

      context 'with embeddings not available' do
        where(:hybrid_issue_search, :ai_global_switch, :issue_embedding, :ai_available, :migration_done) do
          false | false | false | false | false
          true  | false | false | false | false
          false | true  | false | false | false
          false | false | true  | false | false
          false | false | false | true  | false
          false | false | false | false | true
        end

        with_them do
          before do
            stub_feature_flags(search_issues_hybrid_search: hybrid_issue_search)
            stub_feature_flags(ai_global_switch: ai_global_switch)
            stub_feature_flags(elasticsearch_issue_embedding: issue_embedding)
            allow(Gitlab::Saas).to receive(:feature_available?).and_return(ai_available)
            allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
              .with(:add_embedding_to_issues).and_return(migration_done)
          end

          it_behaves_like 'without hybrid search query'
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
    it_behaves_like 'a query filtered by confidentiality'

    describe 'authorization' do
      it 'applies authorization filters' do
        assert_names_in_query(build, with: %w[filters:project:membership:id])
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

  it_behaves_like 'a sorted query'

  describe 'formats' do
    it_behaves_like 'a query that sets source_fields'
    it_behaves_like 'a query formatted for count_only'
  end
end
