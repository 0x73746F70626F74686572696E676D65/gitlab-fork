# frozen_string_literal: true

module Resolvers
  module RemoteDevelopment
    class WorkspacesForAgentResolver < ::Resolvers::BaseResolver
      include ResolvesIds
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::RemoteDevelopment::WorkspaceType.connection_type, null: true
      authorize :admin_cluster
      authorizes_object!

      argument :ids, [::Types::GlobalIDType[::RemoteDevelopment::Workspace]],
        required: false,
        description:
          'Filter workspaces by workspace GlobalIDs. For example, `["gid://gitlab/RemoteDevelopment::Workspace/1"]`.'

      argument :project_ids, [::Types::GlobalIDType[Project]],
        required: false,
        description: 'Filter workspaces by project GlobalID.'

      argument :actual_states, [GraphQL::Types::String],
        required: false,
        description: 'Filter workspaces by actual states.'

      alias_method :agent, :object

      def resolve(**args)
        unless License.feature_available?(:remote_development)
          raise_resource_not_available_error! "'remote_development' licensed feature is not available"
        end

        ::RemoteDevelopment::WorkspacesFinder.execute(
          current_user: current_user,
          agent_ids: [agent.id],
          ids: resolve_ids(args[:ids]).map(&:to_i),
          project_ids: resolve_ids(args[:project_ids]).map(&:to_i),
          actual_states: args[:actual_states] || []
        )
      end
    end
  end
end
