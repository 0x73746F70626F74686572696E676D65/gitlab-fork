# frozen_string_literal: true

module Authz
  class CustomAbility
    def initialize(attributes)
      @attributes = attributes || {}
    end

    def name
      attributes[:name].to_sym
    end

    def allowed?(user, resource)
      return false unless enabled_for?(user, resource)

      name.in?(abilities_for(user, resource))
    end

    class << self
      def allowed?(user, ability, resource)
        new(Gitlab::CustomRoles::Definition.all[ability.to_sym])
          .allowed?(user, resource)
      end
    end

    private

    attr_reader :attributes

    def enabled_for?(user, resource)
      return false if attributes.blank?
      return false unless user.is_a?(User)
      return false unless ::MemberRole.permission_enabled?(name, user)

      custom_roles_enabled?(resource)
    end

    def custom_roles_enabled?(resource)
      return true unless resource.respond_to?(:custom_roles_enabled?)

      resource.custom_roles_enabled?
    end

    def abilities_for_projects(user, projects)
      ::Preloaders::UserMemberRolesInProjectsPreloader.new(
        projects: projects,
        user: user
      ).execute
    end

    def abilities_for_groups(user, groups)
      ::Preloaders::UserMemberRolesInGroupsPreloader.new(
        groups: groups,
        user: user
      ).execute
    end

    def abilities_for(user, resource)
      case resource
      when ::Project
        abilities_for_projects(user, [resource]).fetch(resource.id, [])
      when ::Group
        abilities_for_groups(user, [resource]).fetch(resource.id, [])
      when Ci::Runner
        if resource.project_type?
          abilities_for_projects(user, resource.projects)
        else
          abilities_for_groups(user, resource.groups)
        end.flat_map { |(_id, abilities)| abilities }
      else
        []
      end
    end
  end
end
