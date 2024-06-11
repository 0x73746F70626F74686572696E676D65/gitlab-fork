# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a collection of projects', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:marked_for_deletion_on) { Date.yesterday }
  let_it_be(:group) { create(:group, name: 'public-group', developers: current_user) }
  let_it_be(:projects) { create_list(:project, 5, :public, group: group) }
  let_it_be(:project_marked_for_deletion) do
    create(:project, marked_for_deletion_at: marked_for_deletion_on, group: group, developers: current_user)
  end

  let(:filters) { {} }

  let(:query) do
    graphql_query_for(
      :projects,
      filters,
      "nodes {#{all_graphql_fields_for('Project', max_depth: 1, excluded: ['productAnalyticsState'])} }"
    )
  end

  shared_examples 'a working graphql query that returns data' do
    before do
      post_graphql(query, current_user: current_user)
    end

    it 'returns data' do
      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:projects, :nodes)).to be_present
    end
  end

  context 'when providing marked_for_deletion_on filter' do
    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
    end

    let(:filters) { { marked_for_deletion_on: marked_for_deletion_on } }

    it_behaves_like 'a working graphql query that returns data'

    it 'returns the expected projects' do
      post_graphql(query, current_user: current_user)
      returned_projects = graphql_data_at(:projects, :nodes)

      returned_ids = returned_projects.pluck('id')
      returned_marked_for_deletion_on = returned_projects.pluck('markedForDeletionOn')

      expect(returned_ids).to contain_exactly(project_marked_for_deletion.to_global_id.to_s)
      expect(returned_marked_for_deletion_on).to contain_exactly(marked_for_deletion_on.iso8601)
    end
  end
end
