# frozen_string_literal: true

module Epics
  module SyncAsWorkItem
    SyncAsWorkItemError = Class.new(StandardError)

    # Note: we do not need to sync `lock_version`.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/439716
    ALLOWED_PARAMS = %i[
      title description confidential author created_at updated_at updated_by_id
      last_edited_by_id last_edited_at closed_by_id closed_at state_id external_key
    ].freeze

    def create_work_item_for!
      return unless group.epic_sync_to_work_item_enabled?

      service_response = ::WorkItems::CreateService.new(
        container: group,
        current_user: current_user,
        params: create_params,
        widget_params: extract_widget_params
      ).execute_without_rate_limiting

      handle_response!(:create, service_response)

      service_response.payload[:work_item]
    end

    def update_work_item_for!(epic)
      return true unless group.epic_sync_to_work_item_enabled?
      return true unless epic.work_item

      service_response = ::WorkItems::UpdateService.new(
        container: epic.group,
        current_user: current_user,
        params: update_params(epic),
        widget_params: extract_widget_params
      ).execute(epic.work_item)

      handle_response!(:update, service_response, epic)
    end

    private

    def filtered_params
      params.to_h.with_indifferent_access.slice(*ALLOWED_PARAMS)
    end

    def create_params
      filtered_params.merge(
        work_item_type: WorkItems::Type.default_by_type(:epic),
        extra_params: { synced_work_item: true }
      )
    end

    def update_params(epic)
      update_params = filtered_params.merge({
        updated_by: epic.updated_by,
        updated_at: epic.updated_at,
        extra_params: { synced_work_item: true }
      })

      if epic.edited?
        update_params[:last_edited_at] = epic.last_edited_at
        update_params[:last_edited_by] = epic.last_edited_by
      end

      update_params[:title_html] = epic.title_html if params[:title].present?
      update_params[:description_html] = epic.description_html if params[:description].present?

      update_params
    end

    def handle_response!(action, service_response, epic = nil)
      return true if service_response[:status] == :success

      error_message = Array.wrap(service_response[:message])
      Gitlab::EpicWorkItemSync::Logger.error(
        message: "Not able to #{action} epic work item", error_message: error_message, group_id: group.id,
        epic_id: epic&.id
      )

      raise SyncAsWorkItemError, error_message.join(", ")
    end

    def extract_widget_params
      work_item_type = WorkItems::Type.default_by_type(:epic)

      work_item_type.widgets(group).each_with_object({}) do |widget, widget_params|
        attributes = params.slice(*widget.sync_params)
        next unless attributes.present?

        widget_params[widget.api_symbol] = attributes.merge({ synced_work_item: true })
      end
    end
  end
end
