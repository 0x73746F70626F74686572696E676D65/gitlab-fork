# frozen_string_literal: true

module Epics
  class CloseService < Epics::BaseService
    def execute(epic)
      return epic unless can?(current_user, :update_epic, epic)

      after_close(epic) if close_epic(epic)
    end

    private

    def close_epic(epic)
      work_item = epic.work_item if epic.work_item

      ApplicationRecord.transaction do
        epic.close!
        epic.update!(closed_by: current_user)

        next true unless work_item

        work_item.close!(current_user)
        work_item.update!(closed_at: epic.closed_at, updated_at: epic.updated_at)
      end

    rescue StateMachines::InvalidTransition
      # If we already closed the epic, we don't want to raise an error
      false
    end

    def after_close(epic)
      event_service.close_epic(epic, current_user)
      SystemNoteService.change_status(epic, nil, current_user, epic.state)
      notification_service.close_epic(epic, current_user)
      ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_closed_action(
        author: current_user,
        namespace: epic.group
      )
      log_audit_event(epic, "epic_closed_by_project_bot", "Closed epic #{epic.title}") if current_user.project_bot?
      publish_event(epic)
    end

    def publish_event(epic)
      ::Gitlab::EventStore.publish(
        ::Epics::EpicUpdatedEvent.new(data: { id: epic.id, group_id: epic.group_id })
      )
    end
  end
end
