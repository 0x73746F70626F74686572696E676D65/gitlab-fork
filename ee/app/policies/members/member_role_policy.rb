# frozen_string_literal: true

module Members
  class MemberRolePolicy < BasePolicy
    delegate { @subject.namespace }

    condition(:custom_roles_allowed) do
      ::License.feature_available?(:custom_roles)
    end

    with_options scope: :user, score: 10
    condition(:user_is_owner_of_at_least_one_group) do
      GroupsFinder.new(@user, { min_access_level: Gitlab::Access::OWNER }).execute.any?
    end

    condition(:is_instance_member_role, scope: :subject) do
      @subject.namespace.nil?
    end

    rule { is_instance_member_role & user_is_owner_of_at_least_one_group & custom_roles_allowed }.policy do
      enable :read_member_role
    end

    rule { admin & custom_roles_allowed }.policy do
      enable :admin_member_role
      enable :read_member_role
    end
  end
end
