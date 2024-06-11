# frozen_string_literal: true

module RemoteDevelopment
  module NamespaceClusterAgentMappings
    module Create
      class MappingCreator
        include Messages

        # @param [Hash] context
        # @return [Result]
        def self.create(context)
          context => {
            namespace: Namespace => namespace,
            cluster_agent: Clusters::Agent => cluster_agent,
            user: User => user
          }

          new_mapping = RemoteDevelopmentNamespaceClusterAgentMapping.new(
            cluster_agent_id: cluster_agent.id,
            namespace_id: namespace.id,
            creator_id: user.id
          )

          begin
            new_mapping.save
          rescue ActiveRecord::RecordNotUnique
            return Result.err(NamespaceClusterAgentMappingAlreadyExists.new)
          end

          if new_mapping.errors.present?
            return Result.err(NamespaceClusterAgentMappingCreateFailed.new({ errors: new_mapping.errors }))
          end

          Result.ok(NamespaceClusterAgentMappingCreateSuccessful.new({ namespace_cluster_agent_mapping: new_mapping }))
        end
      end
    end
  end
end
