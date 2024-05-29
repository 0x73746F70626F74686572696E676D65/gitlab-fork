# frozen_string_literal: true

module Resolvers
  module RemoteDevelopment
    class AgentsForNamespaceResolver < ::Resolvers::BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      type Types::Clusters::AgentType.connection_type, null: true

      argument :filter, Types::RemoteDevelopment::NamespaceClusterAgentFilterEnum,
        required: true,
        description: 'Filter the types of cluster agents to return.'

      def resolve(**args)
        unless License.feature_available?(:remote_development)
          raise_resource_not_available_error! "'remote_development' licensed feature is not available"
        end

        unless Feature.enabled?(:remote_development_namespace_agent_authorization, @object.root_ancestor)
          raise_resource_not_available_error!(
            "'remote_development_namespace_agent_authorization' feature flag is disabled"
          )
        end

        raise_resource_not_available_error! unless @object.group_namespace?

        ::RemoteDevelopment::ClusterAgentsFinder.execute(
          namespace: @object,
          filter: args[:filter].downcase.to_sym,
          user: current_user
        )
      rescue Gitlab::Access::AccessDeniedError
        raise_resource_not_available_error!
      end
    end
  end
end
