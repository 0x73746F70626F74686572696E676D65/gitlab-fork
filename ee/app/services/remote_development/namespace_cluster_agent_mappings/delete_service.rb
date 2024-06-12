# frozen_string_literal: true

module RemoteDevelopment
  module NamespaceClusterAgentMappings
    class DeleteService
      include Messages
      include ServiceResponseFactory

      extend MessageSupport

      # @param [Namespace, BatchLoader::GraphQL] namespace
      # @param [Clusters::Agent, BatchLoader::GraphQL] cluster_agent
      # @return [ServiceResponse]
      def execute(namespace:, cluster_agent:)
        response_hash = NamespaceClusterAgentMappings::Delete::Main.main(
          namespace: namespace,
          cluster_agent: cluster_agent
        )

        create_service_response(response_hash)
      end
    end
  end
end
