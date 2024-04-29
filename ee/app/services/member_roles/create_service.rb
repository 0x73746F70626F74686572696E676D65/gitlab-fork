# frozen_string_literal: true

module MemberRoles
  class CreateService < BaseService
    include ::GitlabSubscriptions::SubscriptionHelper

    def execute
      return authorized_error unless allowed?
      return root_group_error if subgroup?

      create_member_role
    end

    private

    def allowed?
      return allowed_for_group? if group

      allowed_for_instance?
    end

    def allowed_for_group?
      return false unless gitlab_com_subscription?
      return false unless can?(current_user, :admin_member_role, group)

      group.custom_roles_enabled?
    end

    def allowed_for_instance?
      return false if gitlab_com_subscription?

      can?(current_user, :admin_member_role)
    end

    def root_group_error
      ::ServiceResponse.error(message: _('Creation of member role is allowed only for root groups'),
        reason: :unauthorized)
    end

    def subgroup?
      return false unless gitlab_com_subscription?

      !group.root?
    end

    def create_member_role
      member_role = MemberRole.new(params.merge(namespace: group))

      if member_role.save
        log_audit_event(member_role, action: :created)

        ::ServiceResponse.success(payload: { member_role: member_role })
      else
        ::ServiceResponse.error(message: member_role.errors.full_messages.join(', '))
      end
    end
  end
end
