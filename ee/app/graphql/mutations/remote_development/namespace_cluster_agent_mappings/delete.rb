# frozen_string_literal: true

module Mutations
  module RemoteDevelopment
    module NamespaceClusterAgentMappings
      class Delete < BaseMutation
        graphql_name 'NamespaceDeleteRemoteDevelopmentClusterAgentMapping'

        include Gitlab::Utils::UsageData

        authorize :admin_remote_development_cluster_agent_mapping

        argument :cluster_agent_id,
          ::Types::GlobalIDType[::Clusters::Agent],
          required: true,
          description: 'GlobalID of the cluster agent to be un-associated from the namespace.'

        argument :namespace_id,
          ::Types::GlobalIDType[::Namespace],
          required: true,
          description: 'GlobalID of the namespace to be un-associated from the cluster agent.'

        def resolve(args)
          unless License.feature_available?(:remote_development)
            raise_resource_not_available_error!("'remote_development' licensed feature is not available")
          end

          namespace_id = args.delete(:namespace_id)
          namespace = authorized_find!(id: namespace_id)

          cluster_agent_id = args.delete(:cluster_agent_id)
          cluster_agent = authorized_find!(id: cluster_agent_id)

          domain_main_class_args = {
            namespace: namespace,
            cluster_agent: cluster_agent
          }

          response = ::RemoteDevelopment::CommonService.execute(
            domain_main_class: ::RemoteDevelopment::NamespaceClusterAgentMappings::Delete::Main,
            domain_main_class_args: domain_main_class_args
          )

          {
            errors: response.errors
          }
        end
      end
    end
  end
end
