# frozen_string_literal: true

module Preloaders
  class UserMemberRolesInProjectsPreloader
    include Gitlab::Utils::StrongMemoize

    def initialize(projects:, user:)
      @projects = if projects.is_a?(Array)
                    Project.select(:id, :namespace_id).where(id: projects)
                  else
                    # Push projects base query in to a sub-select to avoid
                    # table name clashes. Performs better than aliasing.
                    Project.select(:id, :namespace_id).where(id: projects.reselect(:id))
                  end

      @user = user
    end

    def execute
      ::Preloaders::ProjectRootAncestorPreloader.new(projects, :namespace).execute

      ::Gitlab::SafeRequestLoader.execute(
        resource_key: resource_key,
        resource_ids: projects.map(&:id)
      ) do
        abilities_for_user_grouped_by_project
      end
    end

    private

    def abilities_for_user_grouped_by_project
      sql_values_array = projects.filter_map do |project|
        next unless custom_roles_enabled_on?(project)

        [project.id, Arel.sql("ARRAY[#{project.namespace.traversal_ids.join(',')}]")]
      end

      return {} if sql_values_array.empty?

      value_list = Arel::Nodes::ValuesList.new(sql_values_array)

      permissions = MemberRole.all_customizable_project_permissions

      permission_select = permissions.map { |p| "bool_or(custom_permissions.#{p}) AS #{p}" }.join(', ')
      permission_condition = permissions.map do |permission|
        "member_roles.permissions @> ('{\"#{permission}\":true}')::jsonb"
      end.join(' OR ')
      permission_columns = permissions.map { |p| "(member_roles.permissions -> '#{p}')::BOOLEAN as #{p}" }.join(', ')
      result_default = permissions.map { |p| "false AS #{p}" }.join(', ')

      sql = <<~SQL
      SELECT project_ids.project_id, #{permission_select}
        FROM (#{value_list.to_sql}) AS project_ids (project_id, namespace_ids),
        LATERAL (
          (
           #{Member.select(permission_columns)
              .left_outer_joins(:member_role)
              .where("members.source_type = 'Project' AND members.source_id = project_ids.project_id")
              .with_user(user)
              .where(permission_condition)
              .to_sql}
          ) UNION ALL
          (
            #{Member.select(permission_columns)
              .left_outer_joins(:member_role)
              .where("members.source_type = 'Namespace' AND members.source_id IN (SELECT UNNEST(project_ids.namespace_ids) as ids)")
              .with_user(user)
              .where(permission_condition)
              .to_sql}
          ) UNION ALL
          (
            SELECT #{result_default}
          )

        ) AS custom_permissions
        GROUP BY project_ids.project_id;
      SQL

      grouped_by_project = ApplicationRecord.connection.execute(sql).to_a.group_by do |h|
        h['project_id']
      end

      grouped_by_project.transform_values do |value|
        permissions.filter_map do |permission|
          permission if value.find { |custom_role| custom_role[permission.to_s] == true }
        end
      end
    end

    def custom_roles_enabled_on
      Hash.new do |hash, namespace|
        hash[namespace] = namespace&.custom_roles_enabled?
      end
    end
    strong_memoize_attr :custom_roles_enabled_on

    def custom_roles_enabled_on?(project)
      custom_roles_enabled_on[project&.root_ancestor]
    end

    def resource_key
      "member_roles_in_projects:user:#{user.id}"
    end

    attr_reader :projects, :user
  end
end
