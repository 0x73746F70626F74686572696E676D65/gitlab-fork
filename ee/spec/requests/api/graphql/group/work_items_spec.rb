# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a work item list for a group', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, :repository, :public, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }
  let_it_be(:label1) { create(:group_label, group: group) }
  let_it_be(:label2) { create(:group_label, group: group) }
  let_it_be(:milestone1) { create(:milestone, group: group) }
  let_it_be(:milestone2) { create(:milestone, group: group) }

  let_it_be(:project_work_item) { create(:work_item, project: project) }
  let_it_be(:sub_group_work_item) do
    create(
      :work_item,
      namespace: sub_group,
      author: reporter,
      milestone: milestone1,
      labels: [label1]
    )
  end

  let_it_be(:group_work_item) do
    create(
      :work_item,
      namespace: group,
      author: reporter,
      title: 'search_term',
      milestone: milestone2,
      labels: [label2]
    )
  end

  let_it_be(:confidential_work_item) do
    create(:work_item, :confidential, namespace: group, author: reporter)
  end

  let_it_be(:other_work_item) { create(:work_item) }

  let(:work_items_data) { graphql_data['group']['workItems']['nodes'] }
  let(:item_filter_params) { {} }
  let(:current_user) { user }
  let(:query_group) { group }

  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('workItems'.classify, max_depth: 2)}
      }
    QUERY
  end

  shared_examples 'work items resolver without N + 1 queries' do
    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, current_user: current_user)
      end

      expect_graphql_errors_to_be_empty

      create_list(
        :work_item,
        3,
        :epic_with_legacy_epic,
        namespace: group,
        labels: [label1, label2],
        milestone: milestone2,
        author: reporter
      )

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
      expect_graphql_errors_to_be_empty
    end
  end

  describe 'N + 1 queries' do
    context 'when querying root fields' do
      it_behaves_like 'work items resolver without N + 1 queries'
    end

    # We need a separate example since all_graphql_fields_for will not fetch fields from types
    # that implement the widget interface. Only `type` for the widgets field.
    context 'when querying the widget interface' do
      let(:fields) do
        <<~GRAPHQL
          nodes {
            widgets {
              type
              ... on WorkItemWidgetDescription {
                edited
                lastEditedAt
                lastEditedBy {
                  webPath
                  username
                }
              }
              ... on WorkItemWidgetAssignees {
                assignees { nodes { id } }
              }
              ... on WorkItemWidgetHierarchy {
                parent { id }
                children {
                  nodes {
                    id
                  }
                }
              }
              ... on WorkItemWidgetLabels {
                labels { nodes { id } }
                allowsScopedLabels
              }
              ... on WorkItemWidgetMilestone {
                milestone {
                  id
                }
              }
            }
          }
        GRAPHQL
      end

      it_behaves_like 'work items resolver without N + 1 queries'
    end
  end

  def query(params = item_filter_params)
    graphql_query_for(
      'group',
      { 'fullPath' => query_group.full_path },
      query_graphql_field('workItems', params, fields)
    )
  end
end
