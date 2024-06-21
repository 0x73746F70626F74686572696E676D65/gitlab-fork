# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::DestroyService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(container: nil, current_user: user) }

  describe '#execute' do
    context 'when destroying an epic' do
      let_it_be(:group) { create(:group) }
      let_it_be(:label1) { create(:group_label, group: group, title: 'epic-label-1') }
      let_it_be(:label2) { create(:group_label, group: group, title: 'epic-label-2') }
      let_it_be(:epic) { create(:epic, group: group, labels: [label1]) }
      let(:work_item) { epic.sync_object }

      let(:issuable) { epic }
      let(:sync_object) { work_item }

      before do
        sync_object.labels << label2
      end

      it 'deletes the epic and the epic work item' do
        # making sure we have this work item
        expect(WorkItem.find_by_id(sync_object.id)).to be_present

        expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
          change { WorkItem.count }.by(-1)
        )

        expect(sync_object.id).not_to be_nil
        expect(WorkItem.find_by_id(sync_object.id)).to be_nil
      end

      it 'records usage ping epic destroy event' do
        expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(
          :track_epic_destroyed).with(author: user, namespace: group)

        subject.execute(issuable)
      end

      it_behaves_like 'service deleting todos'
      it_behaves_like 'service deleting label links'

      context 'when destroying an epic work item' do
        let(:issuable) { work_item }
        let(:sync_object) { epic }

        it 'deletes the epic and the epic work item' do
          # making sure we have this work item
          expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
            change { WorkItem.count }.by(-1)
          )

          expect(sync_object.id).not_to be_nil
          expect(Epic.find_by_id(sync_object.id)).to be_nil
        end

        it_behaves_like 'service deleting todos'
        it_behaves_like 'service deleting label links'
      end
    end

    context 'when destroying other issuable type' do
      let(:issuable) { create(:issue) }

      it 'does not track usage ping epic destroy event' do
        expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_destroyed)

        subject.execute(issuable)
      end

      RSpec.shared_examples 'logs delete issuable audit event' do
        it 'logs audit event' do
          audit_context = {
            name: "delete_#{issuable.to_ability_name}",
            stream_only: true,
            author: user,
            scope: scope,
            target: issuable,
            message: "Removed #{issuable_name}(#{issuable.title} with IID: #{issuable.iid} and ID: #{issuable.id})",
            target_details: { title: issuable.title, iid: issuable.iid, id: issuable.id, type: issuable_name }
          }

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

          service.execute(issuable)
        end
      end

      context 'when issuable is an issue' do
        let(:issuable_name) { issuable.work_item_type.name }
        let(:scope) { issuable.project }

        it_behaves_like 'logs delete issuable audit event'
      end

      context 'when issuable is an epic' do
        let(:issuable) { create(:epic) }
        let(:issuable_name) { 'Epic' }
        let(:scope) { issuable.group }

        it_behaves_like 'logs delete issuable audit event'
      end

      context 'when issuable is a task' do
        let(:issuable) { create(:work_item, :task) }
        let(:issuable_name) { issuable.work_item_type.name }
        let(:scope) { issuable.project }

        it_behaves_like 'logs delete issuable audit event'
      end

      context 'when issuable is a merge_request' do
        let(:issuable) { create(:merge_request) }
        let(:issuable_name) { 'MergeRequest' }
        let(:scope) { issuable.project }

        it 'calls MergeRequestDestroyAuditor with correct arguments' do
          expect_next_instance_of(Audit::MergeRequestDestroyAuditor, issuable, user) do |instance|
            expect(instance).to receive(:execute)
          end

          service.execute(issuable)
        end

        it 'calls MergeRequestBeforeDestroyAuditor with correct arguments' do
          expect_next_instance_of(Audit::MergeRequestBeforeDestroyAuditor, issuable, user) do |instance|
            expect(instance).to receive(:execute)
          end

          service.execute(issuable)
        end
      end
    end
  end
end
