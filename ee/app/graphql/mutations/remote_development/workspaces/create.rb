# frozen_string_literal: true

module Mutations
  module RemoteDevelopment
    module Workspaces
      class Create < BaseMutation
        graphql_name 'WorkspaceCreate'

        include Gitlab::Utils::UsageData

        authorize :create_workspace

        field :workspace,
          Types::RemoteDevelopment::WorkspaceType,
          null: true,
          description: 'Created workspace.'

        argument :cluster_agent_id,
          ::Types::GlobalIDType[::Clusters::Agent],
          required: true,
          description: 'GlobalID of the cluster agent the created workspace will be associated with.'

        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409772 - Make this a type:enum
        argument :desired_state,
          GraphQL::Types::String,
          required: true,
          description: 'Desired state of the created workspace.'

        argument :editor,
          GraphQL::Types::String,
          required: true,
          description: 'Editor to inject into the created workspace. Must match a configured template.'

        argument :max_hours_before_termination,
          GraphQL::Types::Int,
          required: true,
          description: 'Maximum hours the workspace can exist before it is automatically terminated.'

        argument :project_id,
          ::Types::GlobalIDType[::Project],
          required: true,
          description: 'ID of the project that will provide the Devfile for the created workspace.'

        argument :devfile_ref,
          GraphQL::Types::String,
          required: true,
          description: 'Project repo git ref containing the devfile used to configure the workspace.'

        argument :devfile_path,
          GraphQL::Types::String,
          required: true,
          description: 'Project repo git path containing the devfile used to configure the workspace.'

        argument :variables, [::Types::RemoteDevelopment::WorkspaceVariableInput],
          required: false,
          default_value: [],
          replace_null_with_default: true,
          description: 'Variables to inject into the workspace.'

        def resolve(args)
          unless License.feature_available?(:remote_development)
            raise_resource_not_available_error!("'remote_development' licensed feature is not available")
          end

          project_id = args.delete(:project_id)
          project = authorized_find!(id: project_id)

          cluster_agent_id = args.delete(:cluster_agent_id)

          # NOTE: What the following line actually does - the agent is delegating to the project to check that the user
          # has the :create_workspace ability on the _agent's_ project, which will be true if the user is a developer
          # on the agent's project.
          agent = authorized_find!(id: cluster_agent_id)

          root_namespace = project.root_namespace

          if Feature.enabled?(:remote_development_namespace_agent_authorization, root_namespace)
            relevant_mappings =
              ::RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping
                .for_namespaces(project.project_namespace.traversal_ids)
                .for_agents([agent.id])

            unless relevant_mappings.present?
              raise ::Gitlab::Graphql::Errors::ArgumentError,
                "The provided agent provided must be mapped to an ancestor namespace of the workspace's project."
            end

            valid_relevant_mappings =
              ::RemoteDevelopment::NamespaceClusterAgentMappings::Validations
                .filter_valid_namespace_cluster_agent_mappings(namespace_cluster_agent_mappings: relevant_mappings.to_a)

            unless valid_relevant_mappings.present?
              raise ::Gitlab::Graphql::Errors::ArgumentError,
                "#{relevant_mappings.size} mapping(s) exist between the provided agent and the ancestor namespaces " \
                  "of the workspaces's project, but the agent does not reside within the hierarchy of any of the " \
                  "mapped ancestor namespaces."
            end
          else
            # NOTE: We only do the common-root-namespace check in the create mutation, because if we did it in the
            # update mutation too, and the projects got moved to different namespaces, there would be no way to
            # terminate the workspace via setting the desired state to `Terminated`. However, since the project
            # and agent associations are immutable (cannot be updated via GraphQL, which is the only update path),
            # there's no way that a direct update to the workspace associations could cause this to become invalid -
            # only if the projects or their namespace hierarchies are changed.
            #
            # It is only possible to violate this check by directly calling the GraphQL API - the UI will only
            # present agents for workspace creation which are under the same common root namespace as the
            # workspace project.
            unless root_namespace == agent.project.root_namespace
              raise ::Gitlab::Graphql::Errors::ArgumentError,
                "Workspace's project and agent's project must both be under the same common root group/namespace."
            end
          end

          # noinspection RubyNilAnalysis - This is because the superclass #current_user uses #[], which can return nil
          track_usage_event(:users_creating_workspaces, current_user.id)

          service = ::RemoteDevelopment::Workspaces::CreateService.new(current_user: current_user)
          variables = args.fetch(:variables, []).map(&:to_h)
          params = args.merge(
            agent: agent,
            user: current_user,
            project: project,
            variables: variables
          )
          response = service.execute(params: params)

          response_object = response.success? ? response.payload[:workspace] : nil

          {
            workspace: response_object,
            errors: response.errors
          }
        end
      end
    end
  end
end
