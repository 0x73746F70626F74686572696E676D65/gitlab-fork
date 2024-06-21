# frozen_string_literal: true

module EE
  module WorkItemsHelper
    extend ::Gitlab::Utils::Override

    override :work_items_show_data
    def work_items_show_data(resource_parent)
      super.merge(
        has_issue_weights_feature: resource_parent.licensed_feature_available?(:issue_weights).to_s,
        has_okrs_feature: resource_parent.licensed_feature_available?(:okrs).to_s,
        has_iterations_feature: resource_parent.licensed_feature_available?(:iterations).to_s,
        has_issuable_health_status_feature: resource_parent.licensed_feature_available?(:issuable_health_status).to_s
      )
    end

    override :add_work_item_show_breadcrumb
    def add_work_item_show_breadcrumb(resource_parent, iid)
      if resource_parent.work_items.with_work_item_type.find_by_iid(iid)&.epic_work_item?
        return add_to_breadcrumbs(_('Epics'), group_epics_path(resource_parent))
      end

      super
    end

    override :work_items_list_data
    def work_items_list_data(group, current_user)
      super.merge(
        has_epics_feature: group.licensed_feature_available?(:epics).to_s,
        has_issuable_health_status_feature: group.licensed_feature_available?(:issuable_health_status).to_s,
        has_issue_weights_feature: group.licensed_feature_available?(:issue_weights).to_s,
        has_epics_color_feature: group.licensed_feature_available?(:epic_colors).to_s
      )
    end
  end
end
