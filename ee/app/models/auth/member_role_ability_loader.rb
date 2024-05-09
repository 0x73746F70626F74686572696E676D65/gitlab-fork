# frozen_string_literal: true

module Auth
  class MemberRoleAbilityLoader
    def initialize(user:, resource:, ability:)
      @user = user
      @resource = resource
      @ability = ability
    end

    def has_ability?
      return false unless user.is_a?(User)
      return false unless permission_enabled?

      roles = if resource.is_a?(::Project)
                preloaded_member_roles_for_project[resource.id]
              else # Group
                preloaded_member_roles_for_group[resource.id]
              end

      roles&.include?(ability)
    end

    class << self
      def allowed?(user, resource, ability)
        return false unless resource.custom_roles_enabled?

        new(user: user, resource: resource, ability: ability).has_ability?
      end
    end

    private

    attr_reader :user, :resource, :ability

    def permission_enabled?
      ::MemberRole.permission_enabled?(ability)
    end

    def preloaded_member_roles_for_project
      ::Preloaders::UserMemberRolesInProjectsPreloader.new(
        projects: [resource],
        user: user
      ).execute
    end

    def preloaded_member_roles_for_group
      ::Preloaders::UserMemberRolesInGroupsPreloader.new(
        groups: [resource],
        user: user
      ).execute
    end
  end
end
