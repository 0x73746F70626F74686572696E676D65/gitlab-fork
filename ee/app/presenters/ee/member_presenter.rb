# frozen_string_literal: true

module EE
  module MemberPresenter
    extend ::Gitlab::Utils::Override
    extend ::Gitlab::Utils::DelegatorOverride

    def can_update?
      super || can_override?
    end

    override :can_override?
    def can_override?
      can?(current_user, override_member_permission, member)
    end

    delegator_override :human_access
    def human_access
      return member_role.name if member_role

      super
    end

    override :role_type
    def role_type
      return 'custom' if member_role

      super
    end

    delegator_override :valid_member_roles
    def valid_member_roles
      source = member.source
      member_roles = ::MemberRoles::RolesFinder.new(current_user,
        { parent: source, instance_roles: true }).execute

      if member.highest_group_member
        member_roles = member_roles.select do |role|
          role.base_access_level >= member.highest_group_member.access_level
        end
      end

      member_roles.map do |member_role|
        {
          base_access_level: member_role.base_access_level,
          member_role_id: member_role.id,
          name: member_role.name,
          description: member_role.description,
          occupies_seat: member_role.occupies_seat,
          permissions: member_role.enabled_permission_items.values.map do |permission|
            {
              name: permission[:name].humanize,
              description: permission[:description]
            }
          end
        }
      end
    end

    delegator_override :member_role_description
    def member_role_description
      member_role&.description
    end

    def access_level_for_export
      return human_access unless member_role

      "#{member_role.name} (#{s_('Custom role')})"
    end

    private

    def override_member_permission
      raise NotImplementedError
    end
  end
end
