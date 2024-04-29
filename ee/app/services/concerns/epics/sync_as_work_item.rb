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
    ].freeze

    def create_work_item_for!(epic)
      return unless group.epic_sync_to_work_item_enabled?

      work_item = WorkItem.create!(create_params(epic))
      sync_color!(work_item)
      sync_dates!(epic, work_item)

      work_item
    rescue StandardError => error
      handle_error!(:create, error)
    end

    def update_work_item_for!(epic)
      return true unless group.epic_sync_to_work_item_enabled?
      return true unless epic.work_item

      sync_color!(epic.work_item)
      sync_dates!(epic, epic.work_item)
      epic.work_item.update!(update_params(epic))
    rescue StandardError => error
      handle_error!(:update, error, epic)
    end

    private

    def filtered_params(epic)
      ALLOWED_PARAMS.index_with { |attr| epic[attr] }
    end

    def create_params(epic)
      filtered_params(epic).merge(
        work_item_type: WorkItems::Type.default_by_type(:epic),
        namespace_id: group.id
      )
    end

    def update_params(epic)
      update_params = filtered_params(epic).merge({
        updated_by: epic.updated_by,
        updated_at: epic.updated_at
      })

      if epic.edited?
        update_params[:last_edited_at] = epic.last_edited_at
        update_params[:last_edited_by] = epic.last_edited_by
      end

      update_params[:title_html] = epic.title_html if params[:title].present?
      update_params[:description_html] = epic.description_html if params[:description].present?

      update_params
    end

    def sync_color!(work_item)
      return unless params[:color]

      color = work_item.color || work_item.build_color

      color.color = params[:color]
      color.save!
    end

    def sync_dates!(epic, work_item)
      return unless (params.keys.map(&:to_s) & %w[start_date due_date start_date_is_fixed due_date_is_fixed]).present?

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

      dates_source.save!
    end

    def handle_error!(action, error, epic = nil)
      Gitlab::EpicWorkItemSync::Logger.error(
        message: "Not able to #{action} epic work item",
        error_message: error.message,
        group_id: group.id,
        epic_id: epic&.id)

      Gitlab::ErrorTracking.track_and_raise_exception(error, epic_id: epic&.id)
    end
  end
end
