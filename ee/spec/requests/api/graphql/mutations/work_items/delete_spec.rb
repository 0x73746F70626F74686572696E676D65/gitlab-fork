# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a work item', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  let(:current_user) { developer }
  let(:mutation) { graphql_mutation(:workItemDelete, { 'id' => work_item.to_global_id.to_s }) }
  let(:mutation_response) { graphql_mutation_response(:work_item_delete) }

  context 'when the user is not allowed to delete a work item' do
    let(:work_item) { create(:work_item, project: project) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user has permissions to delete a work item' do
    context 'when deleting an epic work item' do
      context 'when epic work item does not have a synced epic' do
        let_it_be_with_refind(:work_item) do
          create(:work_item, :epic, namespace: group)
        end

        it 'deletes the epic work item' do
          expect do
            post_graphql_mutation(mutation, current_user: owner)
          end.to change { WorkItem.count }.by(-1)
        end
      end

      context 'when epic work item has a synced epic' do
        let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
        let(:work_item) { epic.work_item }

        it 'does not deletes the epic work item' do
          expect do
            post_graphql_mutation(mutation, current_user: owner)
          end.not_to change { WorkItem.count }
        end
      end
    end
  end
end
