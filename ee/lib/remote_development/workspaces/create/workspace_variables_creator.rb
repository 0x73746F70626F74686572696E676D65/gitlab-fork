# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Create
      class WorkspaceVariablesCreator
        include Messages

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.create(context)
          context => {
            workspace: RemoteDevelopment::Workspace => workspace,
            personal_access_token: PersonalAccessToken => personal_access_token,
            current_user: User => user,
            settings: Hash => settings,
            params: Hash => params
          }
          params => {
            variables: Array => user_provided_variables
          }
          # When we have the ability to define variables for workspaces
          # at project/group/instance level, add them here.
          variables = user_provided_variables
          workspace_variables = WorkspaceVariables.variables(
            name: workspace.name,
            dns_zone: workspace.dns_zone,
            personal_access_token_value: personal_access_token.token,
            user_name: user.name,
            user_email: user.email,
            workspace_id: workspace.id,
            settings: settings,
            variables: variables
          )

          workspace_variables.each do |workspace_variable_params|
            workspace_variable = RemoteDevelopment::WorkspaceVariable.new(workspace_variable_params)
            workspace_variable.save

            if workspace_variable.errors.present?
              return Gitlab::Fp::Result.err(
                WorkspaceVariablesModelCreateFailed.new({ errors: workspace_variable.errors })
              )
            end
          end

          Gitlab::Fp::Result.ok(context)
        end
      end
    end
  end
end
