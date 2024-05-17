# frozen_string_literal: true

module Epics
  class ReopenService < Epics::BaseService
    def execute(epic)
      return epic unless can?(current_user, :update_epic, epic)

      after_reopen(epic) if reopen_epic(epic)
    end

    private

    def reopen_epic(epic)
      work_item = epic.work_item if epic.work_item

      ApplicationRecord.transaction do
        epic.reopen!
        next true unless work_item

        work_item.reopen!
        epic.sync_work_item_updated_at
      end

    rescue StateMachines::InvalidTransition
      # If we alrady opened the epic, we don't want to raise an error
      false
    end

    def after_reopen(epic)
      event_service.reopen_epic(epic, current_user)
      SystemNoteService.change_status(epic, nil, current_user, epic.state)
      notification_service.reopen_epic(epic, current_user)
      ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_reopened_action(
        author: current_user,
        namespace: epic.group
      )

      log_audit_event(epic, "epic_reopened_by_project_bot", "Reopened epic #{epic.title}") if current_user.project_bot?

      publish_event(epic)
    end

    def publish_event(epic)
      ::Gitlab::EventStore.publish(
        ::Epics::EpicUpdatedEvent.new(data: { id: epic.id, group_id: epic.group_id })
      )
    end
  end
end
