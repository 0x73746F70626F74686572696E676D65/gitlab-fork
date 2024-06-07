# frozen_string_literal: true

module Resolvers
  module RemoteDevelopment
    class WorkspacesForQueryRootResolver < ::Resolvers::BaseResolver
      include ResolvesIds

      # NOTE: We are intentionally not including Gitlab::Graphql::Authorize::AuthorizeResource, because this resolver
      #       is currently only authorized at the instance admin level for all workspaces in the instance via the
      #       `:read_all_workspaces` ability, so it's not necessary (or performant) to authorize individual workspaces.
      #       Also, including Gitlab::Graphql::Authorize::AuthorizeResource would mix in a many methods related to
      #       "resource" and "object" which are not applicable in this resolver, so we avoid including it and keep
      #       the dependencies of this class more minimal.

      type Types::RemoteDevelopment::WorkspaceType.connection_type, null: true

      argument :ids, [::Types::GlobalIDType[::RemoteDevelopment::Workspace]],
        required: false,
        description:
          'Filter workspaces by workspace GlobalIDs. For example, `["gid://gitlab/RemoteDevelopment::Workspace/1"]`.'

      argument :user_ids, [::Types::GlobalIDType[Project]],
        required: false,
        description: 'Filter workspaces by user GlobalIDs.'

      argument :project_ids, [::Types::GlobalIDType[Project]],
        required: false,
        description: 'Filter workspaces by project GlobalIDs.'

      argument :agent_ids, [::Types::GlobalIDType[::Clusters::Agent]],
        required: false,
        description: 'Filter workspaces by agent GlobalIDs.'

      argument :include_actual_states, [GraphQL::Types::String],
        required: false,
        deprecated: { reason: 'Use actual_states instead', milestone: '16.7' },
        description: 'Filter workspaces by actual states.'

      argument :actual_states, [GraphQL::Types::String],
        required: false,
        description: 'Filter workspaces by actual states.'

      def resolve(**args)
        # rubocop:disable Graphql/ResourceNotAvailableError -- We are intentionally not including Gitlab::Graphql::Authorize::AuthorizeResource - see note at top of class
        unless License.feature_available?(:remote_development)
          raise ::Gitlab::Graphql::Errors::ResourceNotAvailable,
            "'remote_development' licensed feature is not available"
        end
        # rubocop:enable Graphql/ResourceNotAvailableError

        return ::RemoteDevelopment::Workspace.none unless can_read_all_workspaces?

        begin
          ::RemoteDevelopment::WorkspacesFinder.execute(
            current_user: current_user,
            ids: resolve_ids(args[:ids]).map(&:to_i),
            user_ids: resolve_ids(args[:user_ids]).map(&:to_i),
            project_ids: resolve_ids(args[:project_ids]).map(&:to_i),
            agent_ids: resolve_ids(args[:agent_ids]).map(&:to_i),
            actual_states: args[:actual_states] || args[:include_actual_states] || []
          )
        rescue ArgumentError => e
          raise ::Gitlab::Graphql::Errors::ArgumentError, e.message
        end
      end

      private

      def can_read_all_workspaces?
        # noinspection RubyNilAnalysis - This is because the superclass #current_user uses #[], which can return nil
        # TODO: Change the superclass to use context.fetch(:current_user) instead of context[:current_user]
        current_user.can?(:read_all_workspaces)
      end
    end
  end
end
