# frozen_string_literal: true

module RemoteDevelopment
  # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-25400
  class WorkspacePolicy < BasePolicy
    condition(:can_access_workspaces_feature) { user&.can?(:access_workspaces_feature, :global) }
    condition(:can_admin_cluster_agent_for_workspace) { user&.can?(:admin_cluster, workspace.agent) }
    condition(:can_admin_owned_workspace) { workspace_owner? && has_developer_access_to_workspace_project? }

    # NOTE: We use the following guidelines to make this policy more performant and easier to debug
    #
    # 1. Avoid booleans when composing rules, prefer one policy block per condition
    # 2. Place prevent rules first (for performance)
    # 3. Place less-expensive rules first (for performance)
    #
    # ADDITIONAL NOTES:
    #
    # - All "prevent" rules which check conditions for non-anonymous users must be prepended with `~admin &`
    # - For documentation on the Declarative Policy framework, see: https://docs.gitlab.com/ee/development/policies.html
    # - For instructions on debugging policies, see: https://docs.gitlab.com/ee/development/permissions/custom_roles.html#refactoring-abilities

    rule { ~can_access_workspaces_feature }.policy do
      prevent :read_workspace
      prevent :update_workspace
    end

    rule { admin }.enable :read_workspace
    rule { admin }.enable :update_workspace

    rule { can_admin_owned_workspace }.enable :read_workspace
    rule { can_admin_owned_workspace }.enable :update_workspace

    rule { can_admin_cluster_agent_for_workspace }.enable :read_workspace
    rule { can_admin_cluster_agent_for_workspace }.enable :update_workspace

    private

    def workspace
      subject
    end

    def workspace_owner?
      user&.id == workspace.user_id
    end

    def has_developer_access_to_workspace_project?
      can?(:developer_access, workspace.project)
    end
  end
end
