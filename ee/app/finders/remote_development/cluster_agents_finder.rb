# frozen_string_literal: true

module RemoteDevelopment
  class ClusterAgentsFinder
    def self.execute(namespace:, filter:, user:)
      agents = fetch_agents(filter, namespace, user)

      agents.ordered_by_name
    end

    def self.fetch_agents(filter, namespace, user)
      case filter
      when :unmapped
        validate_user_can_read_namespace_agent_mappings!(user: user, namespace: namespace)

        # noinspection RailsParamDefResolve -- A symbol is a valid argument for 'select'
        existing_mapped_agents =
          RemoteDevelopmentNamespaceClusterAgentMapping
            .for_namespaces([namespace.id])
            .select(:cluster_agent_id)

        # NOTE: cluster_agents is only defined for group namespace but that is ok as only group namespaces
        # are supported in the current iteration. However, this method will need to refactored/defined within the
        # Namespace if/when this finder is expected to support mappings for user/project namespaces
        # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/417894
        namespace.cluster_agents.id_not_in(existing_mapped_agents)

      when :directly_mapped
        validate_user_can_read_namespace_agent_mappings!(user: user, namespace: namespace)

        relevant_mappings = RemoteDevelopmentNamespaceClusterAgentMapping.for_namespaces([namespace.id])
        relevant_mappings = NamespaceClusterAgentMappings::Validations.filter_valid_namespace_cluster_agent_mappings(
          namespace_cluster_agent_mappings: relevant_mappings.to_a
        )

        Clusters::Agent.id_in(relevant_mappings.map(&:cluster_agent_id))
      when :available
        relevant_mappings = RemoteDevelopmentNamespaceClusterAgentMapping.for_namespaces(namespace.traversal_ids)
        relevant_mappings = NamespaceClusterAgentMappings::Validations.filter_valid_namespace_cluster_agent_mappings(
          namespace_cluster_agent_mappings: relevant_mappings.to_a
        )

        Clusters::Agent.id_in(relevant_mappings.map(&:cluster_agent_id)).with_remote_development_enabled
      else
        raise "Unsupported value for filter: #{filter}"
      end
    end

    def self.validate_user_can_read_namespace_agent_mappings!(user:, namespace:)
      raise Gitlab::Access::AccessDeniedError unless user.can?(
        :read_remote_development_cluster_agent_mapping,
        namespace
      )
    end
  end
end
