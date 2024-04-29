# frozen_string_literal: true

module WorkItems
  module SyncAsEpic
    SyncAsEpicError = Class.new(StandardError)

    private

    def update_epic_for!(work_item)
      epic = work_item.synced_epic
      return true unless epic
      return true unless epic.group.work_item_sync_to_epic_enabled?

      epic.update!(update_params(work_item))
    rescue StandardError => error
      handle_error!(:update, error, work_item)
    end

    def update_params(work_item)
      epic_params = callback_params

      epic_params[:confidential] = params[:confidential] if params.has_key?(:confidential)
      epic_params[:title] = params[:title] if params.has_key?(:title)
      epic_params[:title_html] = work_item.title_html if params.has_key?(:title)
      epic_params[:updated_by] = work_item.updated_by
      epic_params[:updated_at] = work_item.updated_at
      epic_params[:external_key] = params[:external_key] if params[:external_key]

      if work_item.edited?
        epic_params[:last_edited_at] = work_item.last_edited_at
        epic_params[:last_edited_by] = work_item.last_edited_by
      end

      epic_params
    end

    def callback_params
      callbacks.reduce({}) do |params, callback|
        params.merge!(callback.synced_epic_params) if callback.synced_epic_params.present?
      end
    end

    def handle_error!(action, error, work_item)
      ::Gitlab::EpicWorkItemSync::Logger.error(
        message: "Not able to #{action} epic",
        error_message: error.message,
        group_id: work_item.namespace_id,
        work_item_id: work_item.id
      )

      ::Gitlab::ErrorTracking.track_and_raise_exception(error, work_item_id: work_item.id)
    end
  end
end
