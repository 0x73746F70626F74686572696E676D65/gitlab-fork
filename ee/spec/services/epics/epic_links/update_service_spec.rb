# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epics::EpicLinks::UpdateService, feature_category: :portfolio_management do
  let_it_be(:guest) { create(:user) }
  let_it_be(:group) { create(:group).tap { |g| g.add_guest(guest) } }
  let_it_be(:parent_epic) { create(:epic, group: group) }

  let_it_be_with_reload(:child_epic1) { create_child_epic(1) }
  let_it_be_with_reload(:child_epic2) { create_child_epic(2) }
  let_it_be_with_reload(:child_epic3) { create_child_epic(300) }
  let_it_be_with_reload(:child_epic4) { create_child_epic(400) }

  let(:epic_to_move) { child_epic3 }
  let(:params) { {} }
  let(:current_user) { guest }

  subject(:reorder_child) do
    described_class.new(epic_to_move, current_user, params).execute
  end

  def ordered_epics
    Epic.where(parent_id: parent_epic.id).order('relative_position, id DESC')
  end

  def ordered_work_items
    parent_epic.work_item.reload.work_item_children_by_relative_position
  end

  def create_child_epic(relative_position)
    child = create(:epic, group: group, parent: parent_epic, relative_position: relative_position)
    create(
      :parent_link,
      work_item: child.work_item,
      work_item_parent: parent_epic.work_item,
      relative_position: relative_position
    )

    child
  end

  describe '#execute' do
    shared_examples 'updating timestamps' do
      it 'does not update moved epic' do
        updated_at = epic_to_move.updated_at
        work_item_updated_at = epic_to_move.work_item.updated_at
        reorder_child

        expect(epic_to_move.reload.updated_at.change(usec: 0)).to eq(updated_at.change(usec: 0))
        expect(epic_to_move.work_item.updated_at.change(usec: 0)).to eq(work_item_updated_at.change(usec: 0))
      end

      it 'does not update parent epic' do
        updated_at = parent_epic.updated_at
        work_item_updated_at = parent_epic.work_item.updated_at
        reorder_child

        expect(parent_epic.reload.updated_at.change(usec: 0)).to eq(updated_at.change(usec: 0))
        expect(parent_epic.work_item.updated_at.change(usec: 0)).to eq(work_item_updated_at.change(usec: 0))
      end
    end

    context 'when subepics feature is not available' do
      it 'returns an error' do
        stub_licensed_features(epics: true, subepics: false)

        expect(reorder_child).to eq(message: 'Epic not found for given params', status: :error, http_status: 404)
      end
    end

    context 'when subepics feature is available' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when user has insufficient permissions' do
        let(:current_user) { create(:user) }

        it 'returns an error' do
          expect(reorder_child).to eq(message: 'Epic not found for given params', status: :error, http_status: 404)
        end
      end

      context 'when params are nil' do
        let(:params) { { move_before_id: nil, move_after_id: nil } }

        it 'does not change order of child epics' do
          expect(reorder_child).to include(status: :success)
          expect(ordered_epics).to match_array([child_epic1, child_epic2, child_epic3, child_epic4])
          expect(ordered_work_items).to match_array([
            child_epic1.work_item, child_epic2.work_item, child_epic3.work_item, child_epic4.work_item
          ])
        end
      end

      context 'when moving to start' do
        let(:params) { { move_before_id: nil, move_after_id: child_epic1.id } }

        it_behaves_like 'updating timestamps'

        it 'reorders child epics and sync positions with work items' do
          expect(reorder_child).to include(status: :success)
          expect(ordered_epics).to match_array([child_epic3, child_epic1, child_epic2, child_epic4])
          expect(ordered_work_items).to match_array(
            [child_epic3.work_item, child_epic1.work_item, child_epic2.work_item, child_epic4.work_item]
          )
        end
      end

      context 'when moving to end' do
        let(:params) { { move_before_id: child_epic4.id, move_after_id: nil } }

        it_behaves_like 'updating timestamps'

        it 'reorders child epics and sync positions with work items' do
          expect(reorder_child).to include(status: :success)
          expect(ordered_epics).to match_array([child_epic1, child_epic2, child_epic4, child_epic3])
          expect(ordered_work_items).to match_array(
            [child_epic1.work_item, child_epic2.work_item, child_epic4.work_item, child_epic3.work_item]
          )
        end
      end

      context 'when moving between siblings' do
        let(:params) { { move_before_id: child_epic1.id, move_after_id: child_epic2.id } }

        it_behaves_like 'updating timestamps'

        it 'reorders child epics' do
          expect(reorder_child).to include(status: :success)
          expect(ordered_epics).to match_array([child_epic1, child_epic3, child_epic2, child_epic4])
          expect(ordered_work_items).to match_array(
            [child_epic1.work_item, child_epic3.work_item, child_epic2.work_item, child_epic4.work_item]
          )
        end
      end

      context 'when params are invalid' do
        let_it_be(:other_epic) { create(:epic, group: group) }

        shared_examples 'returns error' do
          it 'does not change order of child epics and returns error' do
            expect(reorder_child).to include(
              message: 'Epic not found for given params', status: :error, http_status: 422
            )
            expect(ordered_epics).to match_array([child_epic1, child_epic2, child_epic3, child_epic4])
            expect(ordered_work_items).to match_array(
              [child_epic1.work_item, child_epic2.work_item, child_epic3.work_item, child_epic4.work_item]
            )
          end
        end

        context 'when move_before_id is not a child of parent epic' do
          let(:params) { { move_before_id: other_epic.id, move_after_id: child_epic2.id } }

          it_behaves_like 'returns error'
        end

        context 'when move_after_id is not a child of parent epic' do
          let(:params) { { move_before_id: child_epic1.id, move_after_id: other_epic.id } }

          it_behaves_like 'returns error'
        end
      end

      context 'when syncing with work items fails' do
        let(:params) { { move_before_id: child_epic4.id, move_after_id: nil } }

        it 'does not change order of child epics and returns error' do
          allow(epic_to_move.work_item.parent_link).to receive(:save!).and_return(false)

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(Epics::SyncAsWorkItem::SyncAsWorkItemError), { moving_epic_id: epic_to_move.id }
          )
          expect(reorder_child).to include(
            message: "Couldn't reorder child due to an internal error.", status: :error, http_status: 422
          )
          expect(ordered_epics).to match_array([child_epic1, child_epic2, child_epic3, child_epic4])
          expect(ordered_work_items).to match_array(
            [child_epic1.work_item, child_epic2.work_item, child_epic3.work_item, child_epic4.work_item]
          )
        end
      end

      context 'when work item should not be synced' do
        let(:params) { { move_before_id: child_epic1.id, move_after_id: child_epic2.id } }
        let(:expected_work_items) do
          [child_epic1.work_item, child_epic2.work_item, child_epic3.work_item, child_epic4.work_item]
        end

        shared_examples 'reordering without syncing relative positions' do
          it 'only changes order of child epics and not the order of synced work items' do
            expect(reorder_child).to include(status: :success)
            expect(ordered_epics).to match_array([child_epic1, child_epic3, child_epic2, child_epic4])
            expect(ordered_work_items).to match_array(expected_work_items)
          end
        end

        context 'when moving child does not have a synced work item parent link' do
          before do
            WorkItems::ParentLink.where(work_item_id: epic_to_move.issue_id).delete_all
            expected_work_items.delete_at(2)
          end

          it_behaves_like 'reordering without syncing relative positions'
        end

        context 'when move_before child does not have a synced work item parent link' do
          before do
            WorkItems::ParentLink.where(work_item_id: child_epic1.issue_id).delete_all
            expected_work_items.delete_at(0)
          end

          it_behaves_like 'reordering without syncing relative positions'
        end

        context 'when move_after child does not have a synced work item parent link' do
          before do
            WorkItems::ParentLink.where(work_item_id: child_epic2.issue_id).delete_all
            expected_work_items.delete_at(1)
          end

          it_behaves_like 'reordering without syncing relative positions'
        end
      end
    end
  end
end
