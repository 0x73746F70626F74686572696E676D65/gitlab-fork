# frozen_string_literal: true

module RemoteDevelopment
  module NamespaceClusterAgentMappings
    class CreateService
      include Messages
      include ServiceResponseFactory

      extend MessageSupport

      # @param [Namespace, BatchLoader::GraphQL] namespace
      # @param [Clusters::Agent, BatchLoader::GraphQL] cluster_agent
      # @param [User] user
      # @return [ServiceResponse]
      def execute(namespace:, cluster_agent:, user:)
        response_hash = NamespaceClusterAgentMappings::Create::Main.main(
          namespace: namespace,
          cluster_agent: cluster_agent,
          user: user
        )

        # Type-check payload using rightward assignment
        if response_hash[:payload]
          response_hash[:payload] => {
            namespace_cluster_agent_mapping: RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping
          }
        end

        create_service_response(response_hash)
      end
    end
  end
end
