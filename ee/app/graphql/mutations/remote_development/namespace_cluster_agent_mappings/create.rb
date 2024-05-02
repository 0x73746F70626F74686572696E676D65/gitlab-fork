# frozen_string_literal: true

module Mutations
  module RemoteDevelopment
    module NamespaceClusterAgentMappings
      class Create < BaseMutation
        graphql_name 'NamespaceCreateRemoteDevelopmentClusterAgentMapping'

        include Gitlab::Utils::UsageData

        authorize :admin_remote_development_cluster_agent_mapping

        argument :cluster_agent_id,
          ::Types::GlobalIDType[::Clusters::Agent],
          required: true,
          description: 'GlobalID of the cluster agent to be associated with the namespace.'

        argument :namespace_id,
          ::Types::GlobalIDType[::Namespace],
          required: true,
          description: 'GlobalID of the namespace to be associated with the cluster agent.'

        def resolve(args)
          unless License.feature_available?(:remote_development)
            raise_resource_not_available_error!("'remote_development' licensed feature is not available")
          end

          namespace_id = args.delete(:namespace_id)
          namespace = authorized_find!(id: namespace_id)

          cluster_agent_id = args.delete(:cluster_agent_id)
          cluster_agent = authorized_find!(id: cluster_agent_id)

          service = ::RemoteDevelopment::NamespaceClusterAgentMappings::CreateService.new
          response = service.execute(
            namespace: namespace,
            cluster_agent: cluster_agent,
            user: current_user
          )

          {
            errors: response.errors
          }
        end
      end
    end
  end
end
