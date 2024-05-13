# frozen_string_literal: true

module WorkItems
  class ValidateEpicWorkItemSyncWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :always
    feature_category :team_planning
    urgency :low
    idempotent!

    def handle_event(event)
      epic, work_item = find_epic_and_work_item_from_event(event)

      return unless epic.present? && work_item.present?

      mismatching_attributes = Gitlab::EpicWorkItemSync::Diff.new(epic, work_item).attributes

      if mismatching_attributes.empty?
        Gitlab::EpicWorkItemSync::Logger.info(
          message: "Epic and work item attributes are in sync after #{action(event)}",
          epic_id: epic.id,
          work_item_id: epic.issue_id
        )
      elsif Epic.find_by_id(epic.id)
        Gitlab::EpicWorkItemSync::Logger.warn(
          message: "Epic and work item attributes are not in sync after #{action(event)}",
          epic_id: epic.id,
          work_item_id: epic.issue_id,
          mismatching_attributes: mismatching_attributes
        )
      else
        Gitlab::EpicWorkItemSync::Logger.info(
          message: "Epic and WorkItem got deleted while finding mismatching attributes",
          epic_id: epic.id,
          work_item_id: epic.issue_id
        )
      end
    end

    private

    def action(event)
      event.is_a?(Epics::EpicCreatedEvent) || event.is_a?(WorkItems::WorkItemCreatedEvent) ? 'create' : 'update'
    end

    def find_epic_and_work_item_from_event(event)
      if event.is_a?(Epics::EpicCreatedEvent) || event.is_a?(Epics::EpicUpdatedEvent)
        epic = Epic.with_work_item.find_by_id(event.data[:id])
        [epic, epic.work_item]
      else
        work_item = WorkItem.find_by_id(event.data[:id])
        [work_item.synced_epic, work_item]
      end
    end
  end
end
