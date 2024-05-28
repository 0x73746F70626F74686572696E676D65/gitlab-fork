# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Create
      class WorkspaceVariables
        GIT_CREDENTIAL_STORE_SCRIPT = <<~SH.chomp
          #!/bin/sh
          # This is a readonly store so we can exit cleanly when git attempts a store or erase action
          if [ "$1" != "get" ];
          then
            exit 0
          fi

          if [ -z "${GL_TOKEN_FILE_PATH}" ];
          then
            echo "We could not find the GL_TOKEN_FILE_PATH variable"
            exit 1
          fi
          password=$(cat ${GL_TOKEN_FILE_PATH})

          # The username is derived from the "user.email" configuration item. Ensure it is set.
          echo "username=does-not-matter"
          echo "password=${password}"
          exit 0
        SH

        # @param [String] name
        # @param [String] dns_zone
        # @param [String] personal_access_token_value
        # @param [String] user_name
        # @param [String] user_email
        # @param [Integer] workspace_id
        # @param [Hash] settings
        # @param [Array<Hash>] variables
        # @return [Array<Hash>]
        def self.variables(
          name:, dns_zone:, personal_access_token_value:, user_name:, user_email:, workspace_id:, settings:, variables:
        )
          settings => { vscode_extensions_gallery: Hash => vscode_extensions_gallery }
          vscode_extensions_gallery => {
            service_url: String => vscode_extensions_gallery_service_url,
            item_url: String => vscode_extensions_gallery_item_url,
            resource_url_template: String => vscode_extensions_gallery_resource_url_template,
          }

          static_variables = [
            {
              key: File.basename(RemoteDevelopment::Workspaces::FileMounts::GITLAB_TOKEN_FILE),
              value: personal_access_token_value,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:file],
              workspace_id: workspace_id
            },
            {
              key: File.basename(RemoteDevelopment::Workspaces::FileMounts::GITLAB_GIT_CREDENTIAL_STORE_FILE),
              value: GIT_CREDENTIAL_STORE_SCRIPT,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:file],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_COUNT',
              value: '3',
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_KEY_0',
              value: "credential.helper",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_VALUE_0',
              value: RemoteDevelopment::Workspaces::FileMounts::GITLAB_GIT_CREDENTIAL_STORE_FILE,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_KEY_1',
              value: "user.name",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_VALUE_1',
              value: user_name,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_KEY_2',
              value: "user.email",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GIT_CONFIG_VALUE_2',
              value: user_email,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_GIT_CREDENTIAL_STORE_FILE_PATH',
              value: RemoteDevelopment::Workspaces::FileMounts::GITLAB_GIT_CREDENTIAL_STORE_FILE,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_TOKEN_FILE_PATH',
              value: RemoteDevelopment::Workspaces::FileMounts::GITLAB_TOKEN_FILE,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_WORKSPACE_DOMAIN_TEMPLATE',
              value: "${PORT}-#{name}.#{dns_zone}",
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_EDITOR_EXTENSIONS_GALLERY_SERVICE_URL',
              value: vscode_extensions_gallery_service_url,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_EDITOR_EXTENSIONS_GALLERY_ITEM_URL',
              value: vscode_extensions_gallery_item_url,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            },
            {
              key: 'GL_EDITOR_EXTENSIONS_GALLERY_RESOURCE_URL_TEMPLATE',
              value: vscode_extensions_gallery_resource_url_template,
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment],
              workspace_id: workspace_id
            }
          ]

          user_provided_variables = variables.map do |variable|
            {
              key: variable.fetch(:key),
              value: variable.fetch(:value),
              variable_type: variable.fetch(:type),
              workspace_id: workspace_id
            }
          end

          static_variables + user_provided_variables
        end
      end
    end
  end
end
