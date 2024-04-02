# frozen_string_literal: true

module MemberRolesHelper
  def member_roles_data(group = nil)
    {
      documentation_path: help_page_path('user/custom_roles'),
      empty_state_svg_path: image_path('illustrations/empty-state/empty-user-settings-md.svg'),
      new_role_path: new_role_path(group),
      group_full_path: group&.full_path
    }
  end

  def manage_member_roles_path(source)
    root_group = source&.root_ancestor
    return unless root_group&.custom_roles_enabled?

    if gitlab_com_subscription? && can?(current_user, :admin_group_member, root_group)
      group_settings_roles_and_permissions_path(root_group)
    elsif current_user&.can_admin_all_resources?
      admin_application_settings_roles_and_permissions_path
    end
  end

  private

  def new_role_path(source)
    root_group = source&.root_ancestor

    if root_group&.custom_roles_enabled? && can?(current_user, :admin_group_member, root_group)
      new_group_settings_roles_and_permission_path(root_group)
    elsif current_user&.can_admin_all_resources? && License.feature_available?(:custom_roles)
      new_admin_application_settings_roles_and_permission_path
    end
  end
end
