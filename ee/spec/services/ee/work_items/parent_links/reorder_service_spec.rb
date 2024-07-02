# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ParentLinks::ReorderService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user, developer_of: group) }

    let_it_be_with_reload(:parent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be_with_reload(:top_adjacent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be_with_reload(:last_adjacent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

    let(:relative_position) { 'AFTER' }
    let(:adjacent_work_item) { top_adjacent }
    let(:base_params) { { target_issuable: work_item, relative_position: relative_position } }
    let(:params) { base_params.merge(adjacent_work_item: adjacent_work_item) }

    let(:work_item_position) { work_item.parent_link.reload.relative_position }
    let(:top_adjacent_position) { top_adjacent.parent_link.reload.relative_position }
    let(:last_adjacent_position) { last_adjacent.parent_link.reload.relative_position }
    let(:synced_moving_object) { work_item.synced_epic.reload }

    subject(:execute) { described_class.new(parent, user, params).execute }

    shared_examples 'reorders the hierarchy' do
      context 'when relative_position is AFTER' do
        let(:relative_position) { 'AFTER' }

        it 'reorders correctly' do
          subject

          expect(work_item_position).to be > top_adjacent_position
          expect(work_item_position).to be < last_adjacent_position

          if synced_moving_object
            expect(synced_moving_object.relative_position).to be > top_adjacent_position
            expect(synced_moving_object.relative_position).to be < last_adjacent_position
          end
        end
      end

      context 'when relative_position is BEFORE' do
        let(:relative_position) { 'BEFORE' }

        it 'reorders correctly' do
          subject

          expect(work_item_position).to be < top_adjacent_position
          expect(work_item_position).to be < last_adjacent_position

          if synced_moving_object
            expect(synced_moving_object.relative_position).to be < top_adjacent_position
            expect(synced_moving_object.relative_position).to be < last_adjacent_position
          end
        end
      end
    end

    shared_examples 'only changes work item' do
      it 'does not change synced moving object relative position but work item one' do
        expect { subject }.to not_change { synced_moving_object.reload.relative_position }
          .and change { work_item.parent_link.reload.relative_position }
      end
    end

    shared_examples 'when saving fails' do |failing_class, expect_error_log: false, expect_error_message: false|
      it "does not change any position when saving #{failing_class}" do
        allow_next_found_instance_of(failing_class) do |instance|
          # Epic and EpicIssue are saved with !
          allow(instance).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
          # WorkItem::ParentLink is saved without a !
          allow(instance).to receive(:save).and_return(false)
        end

        if expect_error_log
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to sync re-ordering work item",
              error_message: 'Record invalid',
              namespace_id: group.id,
              synced_moving_object_id: synced_moving_object.id,
              synced_moving_object_class: synced_moving_object.class
            })

        end

        expect { execute }.to not_change { work_item.parent_link.reload.relative_position }
          .and not_change { synced_moving_object.reload.relative_position }

        if expect_error_message
          expect(execute)
            .to eq({ status: :error, message: "Couldn't re-order due to an internal error.", http_status: 422 })
        end
      end
    end

    before do
      stub_licensed_features(subepics: true)
      stub_feature_flags(synced_epic_work_item_editable: true)
    end

    context 'when adjacent_work_item parent link is missing' do
      let(:synced_moving_object) { nil }

      before do
        create(:parent_link, work_item: work_item, work_item_parent: parent)
      end

      context 'when adjacent work item has a synced epic' do
        it 'creates a new parent link' do
          expect(top_adjacent.reload.parent_link).to be_nil
          expect { execute }.to change { ::WorkItems::ParentLink.count }.by(1)
          expect(top_adjacent.reload.parent_link).to be_present
        end
      end

      context 'when adjacent work item has no synced epic' do
        let_it_be_with_reload(:top_adjacent) { create(:work_item, :epic, namespace: group) }

        it 'does not create a new parent link' do
          expect { execute }.not_to change { WorkItems::ParentLink.count }
        end
      end
    end

    context 'when moving an epic work item' do
      let(:synced_moving_object) { work_item.synced_epic.reload }

      let_it_be_with_reload(:top_adjacent_link) do
        create(:parent_link, work_item: top_adjacent, work_item_parent: parent, relative_position: 20)
      end

      let_it_be_with_reload(:last_adjacent_link) do
        create(:parent_link, work_item: last_adjacent, work_item_parent: parent, relative_position: 30)
      end

      let_it_be_with_reload(:work_item_link) do
        create(:parent_link, work_item: work_item, work_item_parent: parent, relative_position: 40)
      end

      context 'when synced epics for the work items exist' do
        before do
          top_adjacent.synced_epic.update!(parent: parent.synced_epic, relative_position: 20)
          last_adjacent.synced_epic.update!(parent: parent.synced_epic, relative_position: 30)
          work_item.synced_epic.update!(parent: parent.synced_epic, relative_position: 40)
        end

        it_behaves_like 'reorders the hierarchy'

        context 'when synced_work_item param is set' do
          let(:synced_moving_object) { nil }
          let(:params) { base_params.merge(adjacent_work_item: adjacent_work_item, synced_work_item: true) }

          it_behaves_like 'reorders the hierarchy'
          it_behaves_like 'only changes work item' do
            let(:synced_moving_object) { work_item.synced_epic.reload }
          end
        end
      end

      context 'when synced epic for the moving work item do not exist' do
        let(:synced_moving_object) { nil }
        let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }

        it_behaves_like 'reorders the hierarchy'
      end

      context 'when synced epics for the parent epic do not exist' do
        let_it_be_with_reload(:parent) { create(:work_item, :epic, namespace: group) }

        it_behaves_like 'only changes work item'
      end

      it_behaves_like 'when saving fails', Epic, expect_error_log: true, expect_error_message: true
      it_behaves_like 'when saving fails', WorkItems::ParentLink
    end

    context 'when moving an issue work item' do
      let(:synced_moving_object) { epic_issue.reload }

      let_it_be_with_reload(:work_item) { create(:work_item, :issue, namespace: group) }

      let_it_be(:epic_issue) do
        create(:epic_issue, epic: parent.synced_epic, issue: Issue.find(work_item.id), relative_position: 40)
      end

      let_it_be_with_reload(:top_adjacent_link) do
        create(:parent_link, work_item: top_adjacent, work_item_parent: parent, relative_position: 20)
      end

      let_it_be_with_reload(:last_adjacent_link) do
        create(:parent_link, work_item: last_adjacent, work_item_parent: parent, relative_position: 30)
      end

      let_it_be_with_reload(:work_item_link) do
        create(:parent_link, work_item: work_item, work_item_parent: parent, relative_position: 40)
      end

      before do
        top_adjacent.synced_epic.update!(parent: parent.synced_epic, relative_position: 20)
        last_adjacent.synced_epic.update!(parent: parent.synced_epic, relative_position: 30)
      end

      it_behaves_like 'reorders the hierarchy'

      context 'when synced EpicIssue for the moving work item do not exist' do
        let(:synced_moving_object) { nil }
        let_it_be_with_reload(:epic_issue) { nil }

        it_behaves_like 'reorders the hierarchy'
      end

      it_behaves_like 'when saving fails', EpicIssue, expect_error_log: true, expect_error_message: true
      it_behaves_like 'when saving fails', WorkItems::ParentLink
    end
  end
end
