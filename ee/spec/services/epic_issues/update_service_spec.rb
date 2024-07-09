# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicIssues::UpdateService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: create(:group)) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:issues) { create_list(:issue, 4, project: project) }
    let_it_be(:epic_issue1, reload: true) { create(:epic_issue, epic: epic, issue: issues[0], relative_position: 3) }
    let_it_be(:epic_issue2, reload: true) { create(:epic_issue, epic: epic, issue: issues[1], relative_position: 600) }
    let_it_be(:epic_issue3, reload: true) { create(:epic_issue, epic: epic, issue: issues[2], relative_position: 1200) }
    let_it_be(:epic_issue4, reload: true) { create(:epic_issue, epic: epic, issue: issues[3], relative_position: 2000) }
    let_it_be(:default_position_value) { Gitlab::Database::MAX_INT_VALUE / 2 }

    let_it_be_with_refind(:parent_link1) do
      create(:parent_link, work_item: WorkItem.find(epic_issue1.issue.id), work_item_parent: epic.work_item,
        relative_position: epic_issue1.relative_position)
    end

    let_it_be_with_refind(:parent_link2) do
      create(:parent_link, work_item: WorkItem.find(epic_issue2.issue.id), work_item_parent: epic.work_item,
        relative_position: epic_issue2.relative_position)
    end

    let_it_be_with_refind(:parent_link3) do
      create(:parent_link, work_item: WorkItem.find(epic_issue3.issue.id), work_item_parent: epic.work_item,
        relative_position: epic_issue3.relative_position)
    end

    let_it_be_with_refind(:parent_link4) do
      create(:parent_link, work_item: WorkItem.find(epic_issue4.issue.id), work_item_parent: epic.work_item,
        relative_position: epic_issue4.relative_position)
    end

    before do
      stub_licensed_features(epics: true)
      group.add_guest(current_user)
      project.add_guest(current_user)
    end

    def order_issue(issue, params, user = current_user)
      described_class.new(issue, user, params).execute
    end

    def ordered_epics
      EpicIssue.all.order('relative_position, id')
    end

    def ordered_parent_links
      WorkItems::ParentLink.all.order('relative_position, id')
    end

    context 'when moving issues between different epics' do
      before do
        epic = build(:epic, group: group)

        epic_issue3.update_attribute(:epic, epic)
        parent_link3.update_attribute(:work_item_parent, epic.work_item)
      end

      let_it_be(:params) { { move_before_id: epic_issue3.id, move_after_id: epic_issue4.id } }

      subject { order_issue(epic_issue1, params) }

      it 'returns an error' do
        is_expected.to eq(message: 'Epic issue not found for given params', status: :error, http_status: 404)
      end

      it 'does not change the relative_position values' do
        subject

        expect(epic_issue1.relative_position).to eq(3)
        expect(epic_issue2.relative_position).to eq(600)
        expect(epic_issue3.relative_position).to eq(1200)
        expect(epic_issue4.relative_position).to eq(2000)

        expect(parent_link1.relative_position).to eq(3)
        expect(parent_link2.relative_position).to eq(600)
        expect(parent_link3.relative_position).to eq(1200)
        expect(parent_link4.relative_position).to eq(2000)
      end
    end

    context 'moving issue to the first position' do
      let_it_be(:params) { { move_after_id: epic_issue1.id } }

      context 'when some positions are close to each other' do
        before do
          epic_issue2.update_attribute(:relative_position, 4)
          parent_link2.update_attribute(:relative_position, 4)

          order_issue(epic_issue3, params)
        end

        it 'orders issues correctly' do
          expect(ordered_epics).to eq([epic_issue3, epic_issue1, epic_issue2, epic_issue4])
          expect(ordered_parent_links).to eq([parent_link3, parent_link1, parent_link2, parent_link4])
        end
      end

      context 'when there is enough place between positions' do
        before do
          order_issue(epic_issue3, params)
        end

        it 'orders issues correctly' do
          expect(ordered_epics).to eq([epic_issue3, epic_issue1, epic_issue2, epic_issue4])
          expect(ordered_parent_links).to eq([parent_link3, parent_link1, parent_link2, parent_link4])
        end
      end
    end

    context 'moving issue to the third position' do
      let_it_be(:params) { { move_before_id: epic_issue3.id, move_after_id: epic_issue4.id } }

      context 'when some positions are close to each other' do
        before do
          epic_issue2.update_attribute(:relative_position, 1998)
          epic_issue3.update_attribute(:relative_position, 1999)

          parent_link2.update_attribute(:relative_position, 1998)
          parent_link3.update_attribute(:relative_position, 1999)

          order_issue(epic_issue1, params)
        end

        it 'orders issues correctly' do
          expect(ordered_epics).to eq([epic_issue2, epic_issue3, epic_issue1, epic_issue4])
          expect(ordered_parent_links).to eq([parent_link2, parent_link3, parent_link1, parent_link4])
        end
      end

      context 'when all positions are same' do
        before do
          epic_issue1.update_attribute(:relative_position, 10)
          epic_issue2.update_attribute(:relative_position, 10)
          epic_issue3.update_attribute(:relative_position, 10)
          epic_issue4.update_attribute(:relative_position, 10)

          parent_link1.update_attribute(:relative_position, 10)
          parent_link2.update_attribute(:relative_position, 10)
          parent_link3.update_attribute(:relative_position, 10)
          parent_link4.update_attribute(:relative_position, 10)

          order_issue(epic_issue1, params)
        end

        it 'orders affected 2 issues correctly' do
          expect(epic_issue1.reload.relative_position)
            .to be_between(epic_issue3.reload.relative_position, epic_issue4.reload.relative_position)

          expect(parent_link1.reload.relative_position).to eq(epic_issue1.relative_position)
          expect(parent_link1.relative_position)
            .to be_between(parent_link3.reload.relative_position, parent_link4.reload.relative_position)
        end
      end

      context 'when there is enough place between positions' do
        before do
          order_issue(epic_issue1, params)
        end

        it 'orders issues correctly' do
          expect(ordered_epics).to eq([epic_issue2, epic_issue3, epic_issue1, epic_issue4])
          expect(ordered_parent_links).to eq([parent_link2, parent_link3, parent_link1, parent_link4])
        end
      end
    end

    context 'moving issues to the last position' do
      context 'when index of the last possition is correct' do
        before do
          order_issue(epic_issue1, move_before_id: epic_issue4.id)
        end

        it 'orders issues correctly' do
          expect(ordered_epics).to eq([epic_issue2, epic_issue3, epic_issue4, epic_issue1])
          expect(ordered_parent_links).to eq([parent_link2, parent_link3, parent_link4, parent_link1])
        end
      end
    end

    context 'when user has insufficient permissions to update epic issue' do
      let_it_be(:non_member) { create(:user) }

      let(:error_msg) { 'Insufficient permissions to update relation' }

      subject { order_issue(epic_issue1, { move_after_id: epic_issue1.id }, non_member) }

      it 'returns an error if user does not have admin_issue_relation access' do
        group.add_guest(non_member)

        is_expected.to eq(message: error_msg, status: :error, http_status: 403)
      end

      it 'returns an error if user does not have admin_epic_relation access' do
        project.add_guest(non_member)

        is_expected.to eq(message: error_msg, status: :error, http_status: 403)
      end
    end

    context 'synced parent links' do
      let_it_be(:params) { { move_after_id: epic_issue1.id } }
      let(:epic_issue) { epic_issue3 }

      subject(:execute) { described_class.new(epic_issue, current_user, params).execute }

      shared_examples 'is successful' do
        it 'updates the epic_issue' do
          result = execute

          expect(result[:status]).to eq(:success)
          expect(ordered_epics).to eq([epic_issue3, epic_issue1, epic_issue2, epic_issue4])
        end
      end

      context 'when the parent link after does not exist' do
        before do
          parent_link2.destroy!
        end

        it_behaves_like 'is successful'
      end

      context 'when the parent link before does not exist' do
        before do
          parent_link1.destroy!
        end

        it_behaves_like 'is successful'
      end

      context 'when the parent links before and after do not exit' do
        before do
          parent_link1.destroy!
          parent_link2.destroy!
        end

        it_behaves_like 'is successful'
      end

      context 'when the synced parent link does not exist' do
        before do
          parent_link3.destroy!
        end

        it_behaves_like 'is successful'
      end

      context 'when saving the parent link fails' do
        before do
          allow_next_found_instance_of(WorkItems::ParentLink) do |instance|
            allow(instance).to receive(:save).and_return(false)
          end
        end

        it 'rolls back the transaction and returns error' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(Epics::SyncAsWorkItem::SyncAsWorkItemError), { epic_issue_id: epic_issue.id }
          )

          result = execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq("Couldn't reorder child due to an internal error.")
          expect(ordered_epics).to eq([epic_issue1, epic_issue2, epic_issue3, epic_issue4])
          expect(ordered_parent_links).to eq([parent_link1, parent_link2, parent_link3, parent_link4])
        end
      end
    end
  end
end
