# frozen_string_literal: true

module Groups
  class WorkItemsController < Groups::ApplicationController
    feature_category :team_planning

    before_action do
      push_frontend_feature_flag(:notifications_todos_buttons)
      push_force_frontend_feature_flag(:work_items, group&.work_items_feature_flag_enabled?)
      push_force_frontend_feature_flag(:work_items_beta, group&.work_items_beta_feature_flag_enabled?)
      push_force_frontend_feature_flag(:work_items_alpha, group&.work_items_alpha_feature_flag_enabled?)
      push_frontend_feature_flag(:namespace_level_work_items, group)
    end

    def index
      not_found unless Feature.enabled?(:namespace_level_work_items, group)
    end

    def show
      not_found unless Feature.enabled?(:namespace_level_work_items, group)

      # the work_items/:iid route renders a Vue app that takes care of the show and new pages.
      return if show_params[:iid] == 'new'

      @work_item = ::WorkItems::WorkItemsFinder.new(current_user, group_id: group.id)
        .execute.with_work_item_type.find_by_iid(show_params[:iid])
    end

    private

    def show_params
      params.permit(:iid)
    end
  end
end

Groups::WorkItemsController.prepend_mod
