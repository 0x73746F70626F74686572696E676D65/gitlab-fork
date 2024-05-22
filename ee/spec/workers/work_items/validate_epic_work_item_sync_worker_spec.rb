# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ValidateEpicWorkItemSyncWorker, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:epic) { create(:epic, group: group) }
  let_it_be_with_refind(:work_item) { epic.work_item }

  let(:epic_event_data) { { id: epic.id, group_id: group.id } }
  let(:work_item_event_data) { { id: work_item.id, namespace_id: group.id } }
  let(:epic_created_event) { Epics::EpicCreatedEvent.new(data: epic_event_data) }
  let(:epic_updated_event) { Epics::EpicUpdatedEvent.new(data: epic_event_data) }
  let(:work_item_created_event) { WorkItems::WorkItemCreatedEvent.new(data: work_item_event_data) }
  let(:work_item_updated_event) { WorkItems::WorkItemUpdatedEvent.new(data: work_item_event_data) }

  shared_examples 'logs sync and mismatches' do
    context 'when there is no difference' do
      it 'does not log anything' do
        expect(Gitlab::EpicWorkItemSync::Logger).to receive(:info).with(
          message: expected_sync_message,
          epic_id: epic.id,
          work_item_id: work_item.id
        )

        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when there is a difference' do
      before do
        epic.update!(title: "New title")
      end

      it 'logs a warning' do
        expect(Gitlab::EpicWorkItemSync::Logger).to receive(:warn).with(
          message: expected_mismatch_message,
          epic_id: epic.id,
          work_item_id: work_item.id,
          mismatching_attributes: include("title", "lock_version")
        )

        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when epic gets deleted on the database during the check' do
      it 'does not report a mismatch' do
        expect_next_instance_of(Gitlab::EpicWorkItemSync::Diff) do |instance|
          expect(instance).to receive(:attributes).and_return(['title'])
          epic.destroy!
        end

        expect(Gitlab::EpicWorkItemSync::Logger).not_to receive(:warn)
        expect(Gitlab::EpicWorkItemSync::Logger).to receive(:info).with(
          message: "Epic and WorkItem got deleted while finding mismatching attributes",
          epic_id: epic.id,
          work_item_id: work_item.id
        )

        consume_event(subscriber: described_class, event: event)
      end
    end
  end

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

    it_behaves_like 'subscribes to event' do
      let(:event) { work_item_created_event }
    end

    it_behaves_like 'subscribes to event' do
      let(:event) { work_item_updated_event }
    end
  end

  context 'when work item is a project level work item' do
    let(:work_item_event_data) { { id: work_item.id, namespace_id: project.namespace.id } }

    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:work_item) { create(:work_item, :issue, project: create(:project)) }

    it_behaves_like 'ignores the published event' do
      let(:event) { work_item_created_event }
    end

    it_behaves_like 'ignores the published event' do
      let(:event) { work_item_updated_event }
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

    it_behaves_like 'ignores the published event' do
      let(:event) { work_item_created_event }
    end

    it_behaves_like 'ignores the published event' do
      let(:event) { work_item_updated_event }
    end
  end

  context 'when work item has no associated epic' do
    let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }

    it_behaves_like 'ignores the published event' do
      let(:event) { work_item_created_event }
    end

    it_behaves_like 'ignores the published event' do
      let(:event) { work_item_updated_event }
    end

    it 'does not log anything or tries to create a diff' do
      expect(Gitlab::EpicWorkItemSync::Logger).not_to receive(:warn)
      expect(Gitlab::EpicWorkItemSync::Diff).not_to receive(:new)

      consume_event(subscriber: described_class, event: work_item_created_event)
    end
  end

  context 'for epic events' do
    it_behaves_like 'logs sync and mismatches' do
      let(:event) { epic_created_event }
      let(:expected_sync_message) { "Epic and work item attributes are in sync after create" }
      let(:expected_mismatch_message) { "Epic and work item attributes are not in sync after create" }
    end

    it_behaves_like 'logs sync and mismatches' do
      let(:event) { epic_updated_event }
      let(:expected_sync_message) { "Epic and work item attributes are in sync after update" }
      let(:expected_mismatch_message) { "Epic and work item attributes are not in sync after update" }
    end
  end

  context 'for work item events' do
    it_behaves_like 'logs sync and mismatches' do
      let(:event) { work_item_created_event }
      let(:expected_sync_message) { "Epic and work item attributes are in sync after create" }
      let(:expected_mismatch_message) { "Epic and work item attributes are not in sync after create" }
    end

    it_behaves_like 'logs sync and mismatches' do
      let(:event) { work_item_updated_event }
      let(:expected_sync_message) { "Epic and work item attributes are in sync after update" }
      let(:expected_mismatch_message) { "Epic and work item attributes are not in sync after update" }
    end
  end
end
