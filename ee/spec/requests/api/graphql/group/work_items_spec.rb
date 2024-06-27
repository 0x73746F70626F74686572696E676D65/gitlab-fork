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
    ) do |work_item|
      create(:award_emoji, name: 'star', awardable: work_item)
    end
  end

  let_it_be(:group_work_item) do
    create(
      :work_item,
      :epic_with_legacy_epic,
      namespace: group,
      author: reporter,
      title: 'search_term',
      milestone: milestone2,
      labels: [label2]
    ) do |work_item|
      create(:award_emoji, name: 'star', awardable: work_item)
      create(:award_emoji, name: 'rocket', awardable: work_item.sync_object)
    end
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
      post_graphql(query, current_user: current_user) # Warmup

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
      ) do |work_item|
        create(:award_emoji, name: 'eyes', awardable: work_item)
        create(:award_emoji, name: 'rocket', awardable: work_item.sync_object)
        create(:award_emoji, name: 'thumbsup', awardable: work_item.sync_object)
      end

      expect do
        post_graphql(query, current_user: current_user)
      end.not_to exceed_all_query_limit(control).with_threshold(1)
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
      before do
        stub_licensed_features(epics: true)
      end

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
              ... on WorkItemWidgetAwardEmoji {
                upvotes
                downvotes
                awardEmoji {
                  nodes {
                    name
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it_behaves_like 'work items resolver without N + 1 queries'

      context 'when querying for WorkItemWidgetAwardEmoji' do
        it 'queries unified award emojis correctly' do
          post_graphql(query, current_user: current_user)

          data = graphql_data_at(:group, :workItems, :nodes, 0, :widgets)
          data = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['awardEmoji']['nodes']
          expect(data.flat_map(&:values)).to match_array(%w[star rocket])
        end

        it 'fetches unified upvotes and downvotes' do
          create(:award_emoji, name: 'thumbsup', awardable: group_work_item)
          create(:award_emoji, name: 'thumbsup', awardable: group_work_item.sync_object)
          create(:award_emoji, name: 'thumbsup', awardable: group_work_item.sync_object)
          create(:award_emoji, name: 'thumbsdown', awardable: group_work_item.sync_object)

          post_graphql(query, current_user: current_user)

          data = graphql_data_at(:group, :workItems, :nodes, 0, :widgets)
          upvotes = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['upvotes']
          downvotes = data.find { |k| k if k['type'] == 'AWARD_EMOJI' }['downvotes']

          expect(upvotes).to eq(3)
          expect(downvotes).to eq(1)
        end
      end
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
