# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Add linked items to a work item", feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :private) }
  let_it_be(:reporter) { create(:user).tap { |user| project.add_reporter(user) } }
  let_it_be(:work_item) { create(:work_item, project: project) }
  let_it_be(:related1) { create(:work_item, project: project) }
  let_it_be(:related2) { create(:work_item, project: project) }

  let(:mutation_response) { graphql_mutation_response(:work_item_add_linked_items) }
  let(:mutation) { graphql_mutation(:workItemAddLinkedItems, input, fields) }

  let(:ids_to_link) { [related1.to_global_id.to_s, related2.to_global_id.to_s] }
  let(:input) { { 'id' => work_item.to_global_id.to_s, 'workItemsIds' => ids_to_link } }

  let(:fields) do
    <<~FIELDS
      workItem {
        id
        widgets {
          type
          ... on WorkItemWidgetLinkedItems {
            linkedItems {
              edges {
                node {
                  linkType
                  workItem {
                    id
                  }
                }
              }
            }
          }
        }
      }
      errors
      message
    FIELDS
  end

  context 'when the user is not allowed to read the work item' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user has permissions to read the work item' do
    let(:current_user) { reporter }

    it 'links the work items' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { WorkItems::RelatedWorkItemLink.count }.by(2)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['workItem']).to include('id' => work_item.to_global_id.to_s)
      expect(mutation_response['message']).to eq("Successfully linked ID(s): #{related1.id} and #{related2.id}.")
      expect(mutation_response['workItem']['widgets']).to include(
        {
          'linkedItems' => { 'edges' => match_array([
            { 'node' => { 'linkType' => 'relates_to', 'workItem' => { 'id' => related1.to_global_id.to_s } } },
            { 'node' => { 'linkType' => 'relates_to', 'workItem' => { 'id' => related2.to_global_id.to_s } } }
          ]) },
          'type' => 'LINKED_ITEMS'
        }
      )
    end

    context 'when linking a work item fails' do
      let_it_be(:private_project) { create(:project, :private) }
      let_it_be(:related2) { create(:work_item, project: private_project) }

      it 'adds valid items and returns an error message for failed item' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.to change { WorkItems::RelatedWorkItemLink.count }.by(1)

        expect(mutation_response['errors']).to contain_exactly(
          "Item with ID: #{related2.id} cannot be added. " \
          "You don't have permission to perform this action."
        )
      end

      context 'when a work item does not exist' do
        let(:input) do
          {
            'id' => work_item.to_global_id.to_s,
            'workItemsIds' => ["gid://gitlab/WorkItem/#{non_existing_record_id}"]
          }
        end

        it 'returns an error message' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { WorkItems::RelatedWorkItemLink.count }

          expect_graphql_errors_to_include("Couldn't find WorkItem with 'id'=#{non_existing_record_id}")
        end
      end

      context 'when there are more than the max allowed items to link' do
        let(:max_work_items) { Mutations::WorkItems::LinkedItems::Base::MAX_WORK_ITEMS }
        let(:error_msg) { "No more than #{max_work_items} work items can be linked at the same time." }

        before do
          max_work_items.times { |i| ids_to_link.push("gid://gitlab/WorkItem/#{i}") }
        end

        it 'returns an error message' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { WorkItems::RelatedWorkItemLink.count }

          expect_graphql_errors_to_include("No more than #{max_work_items} work items can be linked at the same time.")
        end
      end
    end

    context 'when `linked_work_items` feature flag is disabled' do
      before do
        stub_feature_flags(linked_work_items: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end
end
