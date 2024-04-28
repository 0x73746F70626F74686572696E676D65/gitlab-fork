# frozen_string_literal: true

module EE::Groups::GroupMembersHelper
  extend ::Gitlab::Utils::Override

  override :group_members_list_data
  def group_members_list_data(group, _members, _pagination = {})
    super.merge!({
      disable_two_factor_path: group_two_factor_auth_path(group),
      ldap_override_path: override_group_group_member_path(group, ':id')
    })
  end

  override :group_members_app_data
  def group_members_app_data(
    group, members:, invited:, access_requests:, banned:, include_relations:, search:, pending_members:
  )
    super.merge!({
      can_export_members: can?(current_user, :export_group_memberships, group),
      export_csv_path: export_csv_group_group_members_path(group),
      can_filter_by_enterprise: group.domain_verification_available? && can?(current_user, :admin_group_member, group),
      banned: group_members_list_data(group, banned),
      manage_member_roles_path: manage_member_roles_path(group),
      promotion_request: pending_members.present? ? promotion_pending_members_list_data(pending_members) : [],
      can_approve_access_requests: !::Namespaces::FreeUserCap::Enforcement.new(group.root_ancestor).reached_limit?,
      namespace_user_limit: ::Namespaces::FreeUserCap.dashboard_limit
    })
  end

  def group_member_header_subtext(group)
    if ::Namespaces::FreeUserCap::Enforcement.new(group.root_ancestor).enforce_cap? &&
        can?(current_user, :admin_group_member, group.root_ancestor)
      super + member_header_manage_namespace_members_text(group.root_ancestor)
    else
      super
    end
  end
end
