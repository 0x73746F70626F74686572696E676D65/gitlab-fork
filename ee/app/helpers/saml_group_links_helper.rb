# frozen_string_literal: true

module SamlGroupLinksHelper
  def saml_group_link_role_selector_data(group, current_user)
    data = { standard_roles: group.access_level_roles }

    if group.custom_roles_enabled?
      data[:custom_roles] = MemberRoles::RolesFinder.new(current_user, { parent: group })
        .execute.map { |role| { member_role_id: role.id, name: role.name, base_access_level: role.base_access_level } }
    end

    data
  end

  def saml_group_link_role_name(saml_group_link)
    if saml_group_link.member_role_id.present? && saml_group_link.group.custom_roles_enabled?
      saml_group_link.member_role.name
    else
      ::Gitlab::Access.human_access(saml_group_link.access_level)
    end
  end
end
