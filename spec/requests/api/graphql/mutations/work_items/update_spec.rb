# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a work item' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user).tap { |user| project.add_developer(user) } }
  let_it_be(:work_item, refind: true) { create(:work_item, project: project) }

  let(:work_item_event) { 'CLOSE' }
  let(:input) { { 'stateEvent' => work_item_event, 'title' => 'updated title' } }
  let(:fields) do
    <<~FIELDS
    workItem {
      state
      title
    }
    errors
    FIELDS
  end

  let(:mutation) { graphql_mutation(:workItemUpdate, input.merge('id' => work_item.to_global_id.to_s), fields) }

  let(:mutation_response) { graphql_mutation_response(:work_item_update) }

  context 'the user is not allowed to update a work item' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user has permissions to update a work item' do
    let(:current_user) { developer }

    context 'when the work item is open' do
      it 'closes and updates the work item' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
          work_item.reload
        end.to change(work_item, :state).from('opened').to('closed').and(
          change(work_item, :title).from(work_item.title).to('updated title')
        )

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['workItem']).to include(
          'state' => 'CLOSED',
          'title' => 'updated title'
        )
      end
    end

    context 'when the work item is closed' do
      let(:work_item_event) { 'REOPEN' }

      before do
        work_item.close!
      end

      it 'reopens the work item' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
          work_item.reload
        end.to change(work_item, :state).from('closed').to('opened')

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['workItem']).to include(
          'state' => 'OPEN'
        )
      end
    end

    it_behaves_like 'has spam protection' do
      let(:mutation_class) { ::Mutations::WorkItems::Update }
    end

    context 'when the work_items feature flag is disabled' do
      before do
        stub_feature_flags(work_items: false)
      end

      it 'does not update the work item and returns and error' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
          work_item.reload
        end.to not_change(work_item, :title)

        expect(mutation_response['errors']).to contain_exactly('`work_items` feature flag disabled for this project')
      end
    end

    context 'with description widget input' do
      let(:fields) do
        <<~FIELDS
        workItem {
          description
          widgets {
            type
            ... on WorkItemWidgetDescription {
                    description
            }
          }
        }
        errors
        FIELDS
      end

      it_behaves_like 'update work item description widget' do
        let(:new_description) { 'updated description' }
        let(:input) do
          { 'descriptionWidget' => { 'description' => new_description } }
        end
      end
    end

    context 'with weight widget input' do
      let(:fields) do
        <<~FIELDS
        workItem {
          widgets {
            type
            ... on WorkItemWidgetWeight {
              weight
            }
          }
        }
        errors
        FIELDS
      end

      it_behaves_like 'update work item weight widget' do
        let(:new_weight) { 2 }

        let(:input) do
          { 'weightWidget' => { 'weight' => new_weight } }
        end
      end
    end

    context 'with hierarchy widget input' do
      let(:widgets_response) { mutation_response['workItem']['widgets'] }
      let(:fields) do
        <<~FIELDS
        workItem {
          description
          widgets {
            type
            ... on WorkItemWidgetHierarchy {
              parent {
                id
              }
              children {
                edges {
                  node {
                    id
                  }
                }
              }
            }
          }
        }
        errors
        FIELDS
      end

      context 'when updating parent' do
        let_it_be(:work_item) { create(:work_item, :task, project: project) }

        context 'when parent work item type is invalid' do
          let_it_be(:parent_task) { create(:work_item, :task, project: project) }

          let(:error) { "#{work_item.to_reference} cannot be added: Only Issue can be parent of Task." }
          let(:input) do
            { 'hierarchyWidget' => { 'parentId' => parent_task.to_global_id.to_s }, 'title' => 'new title' }
          end

          it 'returns response with errors' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to not_change(work_item, :work_item_parent).and(not_change(work_item, :title))

            expect(mutation_response['workItem']).to be_nil
            expect(mutation_response['errors']).to match_array([error])
          end
        end

        context 'when parent work item has a valid type' do
          let_it_be(:parent) { create(:work_item, project: project) }

          let(:input) { { 'hierarchyWidget' => { 'parentId' => parent.to_global_id.to_s } } }

          it 'sets the parent for the work item' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change(work_item, :work_item_parent).from(nil).to(parent)

            expect(response).to have_gitlab_http_status(:success)
            expect(widgets_response).to include(
              {
                'children' => { 'edges' => [] },
                'parent' => { 'id' => parent.to_global_id.to_s },
                'type' => 'HIERARCHY'
              }
            )
          end

          context 'when a parent is already present' do
            let_it_be(:existing_parent) { create(:work_item, project: project) }

            before do
              work_item.update!(work_item_parent: existing_parent)
            end

            it 'is replaced with new parent' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
                work_item.reload
              end.to change(work_item, :work_item_parent).from(existing_parent).to(parent)
            end
          end
        end
      end

      context 'when updating children' do
        let_it_be(:valid_child1) { create(:work_item, :task, project: project) }
        let_it_be(:valid_child2) { create(:work_item, :task, project: project) }
        let_it_be(:invalid_child) { create(:work_item, project: project) }

        let(:input) { { 'hierarchyWidget' => { 'childrenIds' => children_ids } } }
        let(:error) do
          "#{invalid_child.to_reference} cannot be added: Only Task can be assigned as a child in hierarchy."
        end

        context 'when child work item type is invalid' do
          let(:children_ids) { [invalid_child.to_global_id.to_s] }

          it 'returns response with errors' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['workItem']).to be_nil
            expect(mutation_response['errors']).to match_array([error])
          end
        end

        context 'when child work item type is valid' do
          let(:children_ids) { [valid_child1.to_global_id.to_s, valid_child2.to_global_id.to_s] }

          it 'updates the work item children' do
            expect do
              post_graphql_mutation(mutation, current_user: current_user)
              work_item.reload
            end.to change(work_item.work_item_children, :count).by(2)

            expect(response).to have_gitlab_http_status(:success)
            expect(widgets_response).to include(
              {
                'children' => { 'edges' => [
                  { 'node' => { 'id' => valid_child2.to_global_id.to_s } },
                  { 'node' => { 'id' => valid_child1.to_global_id.to_s } }
                ] },
                'parent' => nil,
                'type' => 'HIERARCHY'
              }
            )
          end
        end
      end
    end
  end
end
