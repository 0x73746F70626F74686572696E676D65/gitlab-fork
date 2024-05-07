# frozen_string_literal: true

module WorkItems
  class ValidateEpicWorkItemSyncWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :always
    feature_category :team_planning
    urgency :low
    idempotent!

    def handle_event(event)
      epic = Epic.with_work_item.find_by_id(event.data[:id])

      return unless epic.present? && epic.work_item.present?

      mismatching_attributes = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item).attributes

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
      event.is_a?(Epics::EpicCreatedEvent) ? 'create' : 'update'
    end
  end
end
