# frozen_string_literal: true

module RemoteDevelopment
  module NamespaceClusterAgentMappings
    module Create
      class ClusterAgentValidator
        include Messages

        # @param [Hash] context
        # @return [Result]
        def self.validate(context)
          context => {
            namespace: Namespace => namespace,
            cluster_agent: Clusters::Agent => cluster_agent,
          }

          return Result.ok(context) unless cluster_agent.project.project_namespace.traversal_ids.exclude?(namespace.id)

          Result.err(NamespaceClusterAgentMappingCreateValidationFailed.new({
            details: "Cluster Agent's project must be nested within the namespace"
          }))
        end
      end
    end
  end
end
