# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a collection of blobs with multiple matches in a single file', feature_category: :global_search do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, :repository, name: 'awesome project', group: group) }
  let(:fields) { all_graphql_fields_for(Types::Search::Blob::BlobSearchType, max_depth: 4) }

  let(:query) { graphql_query_for(:blobSearch, { search: 'test', group_id: "gid://gitlab/Group/#{group.id}" }, fields) }

  before do
    stub_licensed_features(zoekt_code_search: true)
  end

  context 'when zoekt is enabled for a group', :zoekt_settings_enabled do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      zoekt_ensure_project_indexed!(project)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    describe 'validation for verify_repository_ref!' do
      let(:existing_project_id) { "gid://gitlab/Project/#{project.id}" }
      let(:non_existing_project_id) { "gid://gitlab/Project/#{non_existing_record_id}" }
      let(:default_ref) { project.default_branch }

      using RSpec::Parameterized::TableSyntax
      where(:ref, :p_id, :error) do
        nil               | ref(:existing_project_id)     | false
        ref(:default_ref) | ref(:existing_project_id)     | false
        'dummy'           | ref(:non_existing_project_id) | false
        'dummy'           | ref(:existing_project_id)     | true
        'dummy'           | nil                           | false
      end
      with_them do
        let(:query) { graphql_query_for(:blobSearch, { search: 'test', repository_ref: ref, project_id: p_id }) }
        before do
          post_graphql(query, current_user: current_user)
        end

        it 'raises exception with message Search is only allowed in project default branch when error is true' do
          if error
            expect_graphql_errors_to_include(/Search is only allowed in project default branch/)
          else
            expect_graphql_errors_to_be_empty
          end
        end
      end
    end

    context 'when global search is disabled for blobs' do
      before do
        stub_feature_flags(global_search_code_tab: false)
      end

      context 'when group_id and project_id not passed' do
        let(:query) { graphql_query_for(:blobSearch, { search: 'test' }) }

        it 'raises error Global search is not enabled for this scope' do
          post_graphql(query, current_user: current_user)
          expect_graphql_errors_to_include(/Global search is not enabled for this scope/)
        end
      end
    end

    context 'when search term is invalid' do
      let(:query) { graphql_query_for(:blobSearch, { search: '*', group_id: "gid://gitlab/Group/#{group.id}" }) }

      it 'raises error parsing regexp: missing argument to repetition operator' do
        post_graphql(query, current_user: current_user)
        expect_graphql_errors_to_include(%r{error parsing regexp: missing argument to repetition operator: `*`})
      end
    end

    it 'returns the correct fields' do
      post_graphql(query, current_user: current_user)
      expect(graphql_data_at(:blobSearch))
        .to include('fileCount', 'files', 'matchCount', 'perPage', 'searchLevel', 'searchType')
      file = graphql_data_at(:blobSearch, :files).find { |f| f['chunks'].any? }
      expect(file).to include('path', 'fileUrl', 'blameUrl', 'matchCountTotal', 'matchCount', 'chunks', 'projectPath')
      chunk = file['chunks'].first
      expect(chunk).to include('lines', 'matchCountInChunk')
      line = chunk['lines'].first
      expect(line).to include('lineNumber', 'richText', 'text')
    end
  end

  context 'when zoekt is disabled for a group', :zoekt_settings_enabled do
    it 'raises error Zoekt search is not available for this request' do
      post_graphql(query, current_user: current_user)
      expect_graphql_errors_to_include(/Zoekt search is not available for this request/)
    end
  end
end
