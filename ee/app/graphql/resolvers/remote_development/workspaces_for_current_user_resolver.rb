# frozen_string_literal: true

module Resolvers
  module RemoteDevelopment
    class WorkspacesForCurrentUserResolver < ::Resolvers::BaseResolver
      include ResolvesIds
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::RemoteDevelopment::WorkspaceType.connection_type, null: true

      argument :ids, [::Types::GlobalIDType[::RemoteDevelopment::Workspace]],
        required: false,
        description:
          'Filter workspaces by workspace ids. For example, `["gid://gitlab/RemoteDevelopment::Workspace/1"]`.'

      argument :project_ids, [::Types::GlobalIDType[Project]],
        required: false,
        description: 'Filter workspaces by project ids.'

      argument :agent_ids, [::Types::GlobalIDType[::Clusters::Agent]],
        required: false,
        description: 'Filter workspaces by agent ids.'

      argument :include_actual_states, [GraphQL::Types::String],
        required: false,
        deprecated: { reason: 'Use actual_states instead', milestone: '16.7' },
        description: 'Filter workspaces by actual states.'

      argument :actual_states, [GraphQL::Types::String],
        required: false,
        description: 'Filter workspaces by actual states.'

      def resolve(**args)
        unless License.feature_available?(:remote_development)
          raise_resource_not_available_error! "'remote_development' licensed feature is not available"
        end

        ::RemoteDevelopment::WorkspacesFinder.execute(
          current_user: current_user,
          user_ids: [current_user.id],
          ids: resolve_ids(args[:ids]).map(&:to_i),
          project_ids: resolve_ids(args[:project_ids]).map(&:to_i),
          agent_ids: resolve_ids(args[:agent_ids]).map(&:to_i),
          actual_states: args[:actual_states] || args[:include_actual_states] || []
        )
      end
    end
  end
end
