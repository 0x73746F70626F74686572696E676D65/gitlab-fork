# frozen_string_literal: true

module WorkItems
  module SyncAsEpic
    SyncAsEpicError = Class.new(StandardError)

    private

    def create_epic_for!(work_item)
      return true unless work_item.namespace.work_item_sync_to_epic_enabled?

      epic = Epic.create!(create_params(work_item))

      work_item.relative_position = epic.id
      work_item.save!(touch: false)
    rescue StandardError => error
      handle_error!(:create, error, work_item)
    end

    def update_epic_for!(work_item)
      epic = work_item.synced_epic
      return true unless epic
      return true unless epic.group.work_item_sync_to_epic_enabled?

      epic.update!(update_params(work_item))
    rescue StandardError => error
      handle_error!(:update, error, work_item)
    end

    def create_params(work_item)
      epic_params = {}

      epic_params[:author] = work_item.author
      epic_params[:group] = work_item.namespace
      epic_params[:issue_id] = work_item.id
      epic_params[:iid] = work_item.iid
      epic_params[:created_at] = work_item.created_at

      parent_link = WorkItems::ParentLink.find_by_work_item_id(work_item.id)

      if parent_link && parent_link.work_item_parent.synced_epic
        epic_params[:relative_position] = parent_link.relative_position
        epic_params[:parent_id] = parent_link.work_item_parent.synced_epic.id
      end

      epic_params
        .merge(callback_params)
        .merge(base_attributes_params(work_item))
    end

    def update_params(work_item)
      callback_params
        .merge(base_attributes_params(work_item))
    end

    def base_attributes_params(work_item)
      base_params = {}

      if params.has_key?(:title)
        base_params[:title] = params[:title]
        base_params[:title_html] = work_item.title_html
      end

      base_params[:confidential] = params[:confidential] if params.has_key?(:confidential)
      base_params[:updated_by] = work_item.updated_by
      base_params[:updated_at] = work_item.updated_at
      base_params[:external_key] = params[:external_key] if params[:external_key]

      if work_item.edited?
        base_params[:last_edited_at] = work_item.last_edited_at
        base_params[:last_edited_by] = work_item.last_edited_by
      end

      base_params
    end

    def callback_params
      callbacks.reduce({}) do |params, callback|
        next params unless callback.synced_epic_params.present?

        params.merge!(callback.synced_epic_params)
      end
    end

    def handle_error!(action, error, work_item)
      ::Gitlab::EpicWorkItemSync::Logger.error(
        message: "Not able to #{action} epic",
        error_message: error.message,
        group_id: work_item.namespace_id,
        work_item_id: work_item&.id
      )

      ::Gitlab::ErrorTracking.track_and_raise_exception(error, group_id: work_item.namespace_id)
    end
  end
end
