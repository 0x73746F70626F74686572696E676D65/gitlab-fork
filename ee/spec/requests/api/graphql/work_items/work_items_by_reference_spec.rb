# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.workItemsByReference (EE)', feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:public_group) { create(:group, :public, guests: current_user) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:public_project) { create(:project, :repository, :public, group: public_group) }
  let_it_be(:task) { create(:work_item, :task, project: public_project) }
  let_it_be(:work_item_epic1) { create(:work_item, :epic, namespace: public_group) }
  let_it_be(:work_item_epic2) { create(:work_item, :epic, namespace: public_group) }
  let_it_be(:private_work_item_epic) { create(:work_item, :epic, namespace: private_group) }

  let(:references) do
    [
      task.to_reference(full: true),
      work_item_epic1.to_reference(full: true),
      Gitlab::UrlBuilder.build(work_item_epic2),
      private_work_item_epic.to_reference(full: true)
    ]
  end

  shared_examples 'response with accessible work items' do
    let(:items) { [work_item_epic2, work_item_epic1, task] }

    it_behaves_like 'a working graphql query that returns data' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    it 'returns accessible work item' do
      post_graphql(query, current_user: current_user)

      expected_items = items.map { |item| a_graphql_entity_for(item) }
      expect(graphql_data_at('workItemsByReference', 'nodes')).to match(expected_items)
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      post_graphql(query, current_user: current_user) # warm up

      control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, current_user: current_user)
      end
      expect(graphql_data_at('workItemsByReference', 'nodes').size).to eq(3)

      extra_work_items = create_list(:work_item, 3, :epic, namespace: public_group)
      refs = references + extra_work_items.map { |item| item.to_reference(full: true) }

      expect do
        post_graphql(query(refs: refs), current_user: current_user)
      end.not_to exceed_all_query_limit(control_count)
      expect(graphql_data_at('workItemsByReference', 'nodes').size).to eq(6)
    end

    context 'with access to private group' do
      let(:items) { [private_work_item_epic, work_item_epic2, work_item_epic1, task] }

      before_all do
        private_group.add_guest(current_user)
      end

      it 'returns accessible work item' do
        post_graphql(query, current_user: current_user)

        expected_items = items.map { |item| a_graphql_entity_for(item) }
        expect(graphql_data_at('workItemsByReference', 'nodes')).to match(expected_items)
      end
    end
  end

  context 'when context is a project' do
    let(:path) { public_project.full_path }

    it_behaves_like 'response with accessible work items'
  end

  context 'when context is a group' do
    let(:path) { public_group.full_path }

    it_behaves_like 'response with accessible work items'
  end

  def query(namespace_path: path, refs: references)
    fields = <<~GRAPHQL
      nodes {
        id
        title
      }
    GRAPHQL

    graphql_query_for('workItemsByReference', { contextNamespacePath: namespace_path, refs: refs }, fields)
  end
end
