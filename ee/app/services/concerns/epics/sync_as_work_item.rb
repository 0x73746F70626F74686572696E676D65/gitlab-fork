# frozen_string_literal: true

module Epics
  module SyncAsWorkItem
    extend ActiveSupport::Concern

    SyncAsWorkItemError = Class.new(StandardError)

    # Note: we do not need to sync `lock_version`.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/439716
    ALLOWED_PARAMS = %i[
      iid title description confidential author_id created_at updated_at updated_by_id
      last_edited_by_id last_edited_at closed_by_id closed_at state_id external_key
      imported_from
    ].freeze

    def create_work_item_for(epic)
      work_item = WorkItem.create(create_params(epic))

      if work_item.errors.any?
        track_error(:create, work_item.errors.full_messages.to_sentence)
        return work_item
      end

      sync_color(epic, work_item)
      sync_dates(epic, work_item)

      work_item.save!(touch: false)
      work_item
    rescue StandardError => error
      raise_error!(:create, error)
    end

    def update_work_item_for!(epic)
      return true unless epic.work_item

      sync_color(epic, epic.work_item)
      sync_dates(epic, epic.work_item)
      epic.work_item.assign_attributes(update_params(epic))

      epic.work_item.save!(touch: false)
    rescue StandardError => error
      raise_error!(:update, error, epic)
    end

    private

    def create_params(epic)
      ALLOWED_PARAMS.index_with { |attr| epic[attr] }
                    .merge(work_item_type: WorkItems::Type.default_by_type(:epic), namespace_id: group.id)
    end

    def update_params(epic)
      epic.previous_changes.keys.map(&:to_sym)
        .intersection(ALLOWED_PARAMS + %i[updated_at title_html description_html])
        .index_with { |attr| epic[attr] }
    end

    def sync_color(epic, work_item)
      work_item_color = work_item.color || work_item.build_color

      # only set non default color or remove the color if default color is set to epic
      if epic.color.to_s == ::Epic::DEFAULT_COLOR.to_s && work_item.color.new_record?
        work_item.color = nil
      else
        work_item_color.color = epic.color
        work_item.color = work_item_color
      end
    end

    def sync_dates(epic, work_item)
      dates_source = work_item.dates_source || work_item.build_dates_source

      dates_source.start_date = epic.start_date
      dates_source.start_date_fixed = epic.start_date_fixed
      dates_source.start_date_is_fixed = epic.start_date_is_fixed || false
      dates_source.start_date_sourcing_milestone_id = epic.start_date_sourcing_milestone_id
      dates_source.start_date_sourcing_work_item_id = epic.start_date_sourcing_epic&.issue_id

      dates_source.due_date = epic.due_date
      dates_source.due_date_fixed = epic.due_date_fixed
      dates_source.due_date_is_fixed = epic.due_date_is_fixed || false
      dates_source.due_date_sourcing_milestone_id = epic.due_date_sourcing_milestone_id
      dates_source.due_date_sourcing_work_item_id = epic.due_date_sourcing_epic&.issue_id

      work_item.dates_source = dates_source
    end

    def raise_error!(action, error, epic = nil)
      log_error(action, error.message, epic)

      Gitlab::ErrorTracking.track_and_raise_exception(error, epic_id: epic&.id)
    end

    def track_error(action, error_message, epic = nil)
      log_error(action, error_message, epic)

      Gitlab::ErrorTracking.track_exception(SyncAsWorkItemError.new(error_message), epic_id: epic&.id)
    end

    def log_error(action, error_message, epic)
      Gitlab::EpicWorkItemSync::Logger.error(
        message: "Not able to #{action} epic work item",
        error_message: error_message,
        group_id: group.id,
        epic_id: epic&.id)
    end
  end
end
