# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ValidateEpicWorkItemSyncWorker, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group) }

  let(:data) { { id: epic.id, group_id: group.id } }
  let(:epic_created_event) { Epics::EpicCreatedEvent.new(data: data) }
  let(:epic_updated_event) { Epics::EpicUpdatedEvent.new(data: data) }

  context 'when validate_epic_work_item_sync is enabled for group' do
    before do
      stub_feature_flags(validate_epic_work_item_sync: group)
    end

    it_behaves_like 'subscribes to event' do
      let(:event) { epic_created_event }
    end

    it_behaves_like 'subscribes to event' do
      let(:event) { epic_updated_event }
    end
  end

  context 'when validate_epic_work_item_sync is not enabled for group' do
    before do
      stub_feature_flags(validate_epic_work_item_sync: false)
    end

    it_behaves_like 'ignores the published event' do
      let(:event) { epic_created_event }
    end

    it_behaves_like 'ignores the published event' do
      let(:event) { epic_updated_event }
    end
  end

  context 'when epic has no associated work item' do
    let_it_be_with_reload(:epic) { create(:epic, :without_synced_work_item, group: group) }

    it 'does not log anything or tries to create a diff' do
      expect(Gitlab::EpicWorkItemSync::Logger).not_to receive(:warn)
      expect(Gitlab::EpicWorkItemSync::Diff).not_to receive(:new)

      consume_event(subscriber: described_class, event: epic_created_event)
    end
  end

  context 'when epic has an associated work item' do
    let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item) }
    let(:work_item) { epic.work_item }

    context 'when there is no difference' do
      it 'does not log anything' do
        expect(Gitlab::EpicWorkItemSync::Logger).to receive(:info).with(
          message: "Epic and work item attributes are in sync after create",
          epic_id: epic.id,
          work_item_id: work_item.id
        )

        consume_event(subscriber: described_class, event: epic_created_event)
      end
    end

    context 'when there is a difference' do
      before do
        epic.update!(title: "New title")
      end

      context 'on epic creation event' do
        it 'logs a warning' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:warn).with(
            message: "Epic and work item attributes are not in sync after create",
            epic_id: epic.id,
            work_item_id: work_item.id,
            mismatching_attributes: include("title", "lock_version")
          )

          consume_event(subscriber: described_class, event: epic_created_event)
        end
      end

      context 'on epic update event' do
        it 'logs a warning' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:warn).with(
            message: "Epic and work item attributes are not in sync after update",
            epic_id: epic.id,
            work_item_id: work_item.id,
            mismatching_attributes: include("title", "lock_version")
          )

          consume_event(subscriber: described_class, event: epic_updated_event)
        end
      end

      context 'when epic gets deleted on the database during the check' do
        it 'does not report a mismatch' do
          expect_next_instance_of(Gitlab::EpicWorkItemSync::Diff) do |instance|
            expect(instance).to receive(:attributes).and_call_original
            epic.destroy!
          end

          expect(Gitlab::EpicWorkItemSync::Logger).not_to receive(:warn)
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:info).with(
            message: "Epic and WorkItem got deleted while finding mismatching attributes",
            epic_id: epic.id,
            work_item_id: work_item.id
          )

          consume_event(subscriber: described_class, event: epic_updated_event)
        end
      end
    end
  end
end
