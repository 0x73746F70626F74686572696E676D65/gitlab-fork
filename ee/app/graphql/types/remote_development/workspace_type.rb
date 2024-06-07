# frozen_string_literal: true

module Types
  module RemoteDevelopment
    class WorkspaceType < ::Types::BaseObject
      graphql_name 'Workspace'
      description 'Represents a remote development workspace'

      authorize :read_workspace

      field :id, ::Types::GlobalIDType[::RemoteDevelopment::Workspace],
        null: false, description: 'Global ID of the workspace.'

      field :cluster_agent, ::Types::Clusters::AgentType,
        null: false,
        method: :agent,
        description: 'Kubernetes agent associated with the workspace.'

      field :project_id, GraphQL::Types::ID,
        null: false, description: 'ID of the project that contains the devfile for the workspace.'

      field :user, ::Types::UserType,
        null: false, description: 'Owner of the workspace.'

      field :name, GraphQL::Types::String,
        null: false, description: 'Name of the workspace in Kubernetes.'

      field :namespace, GraphQL::Types::String,
        null: false, description: 'Namespace of the workspace in Kubernetes.'

      # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409772 - Make this a type:enum
      field :desired_state, GraphQL::Types::String,
        null: false, description: 'Desired state of the workspace.'

      field :desired_state_updated_at, Types::TimeType, # rubocop:disable GraphQL/ExtractType -- We don't want to extract this to a type, it's just a timestamp field
        null: false, description: 'Timestamp of the last update to the desired state.'

      # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409772 - Make this a type:enum
      field :actual_state, GraphQL::Types::String,
        null: false, description: 'Actual state of the workspace.'

      field :responded_to_agent_at, Types::TimeType,
        null: true,
        description: 'Timestamp of the last response sent to the GitLab agent for Kubernetes for the workspace.'

      field :url, GraphQL::Types::String,
        null: false, description: 'URL of the workspace.'

      field :editor, GraphQL::Types::String,
        null: false, description: 'Editor used to configure the workspace. Must match a configured template.'

      field :max_hours_before_termination, GraphQL::Types::Int,
        null: false, description: 'Number of hours until the workspace automatically terminates.'

      field :devfile_ref, GraphQL::Types::String,
        null: false, description: 'Git reference that contains the devfile used to configure the workspace.'

      field :devfile_path, GraphQL::Types::String,
        null: false, description: 'Path to the devfile used to configure the workspace.'

      field :devfile_web_url, GraphQL::Types::String, # rubocop:disable GraphQL/ExtractType -- We don't want to extract this to a type, it would cause confusion with the devfile field
        null: false, description: 'Web URL of the devfile used to configure the workspace.'

      field :devfile, GraphQL::Types::String,
        null: false, description: 'Source YAML of the devfile used to configure the workspace.'

      field :processed_devfile, GraphQL::Types::String,
        null: false, description: 'Processed YAML of the devfile used to configure the workspace.'

      field :deployment_resource_version, GraphQL::Types::Int,
        null: true, description: 'Version of the deployment resource for the workspace.'

      field :created_at, Types::TimeType,
        null: false, description: 'Timestamp of when the workspace was created.'

      field :updated_at, Types::TimeType,
        null: false, description: 'Timestamp of the last update to any mutable workspace property.'

      def project_id
        "gid://gitlab/Project/#{object.project_id}"
      end
    end
  end
end
