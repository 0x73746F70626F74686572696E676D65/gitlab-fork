# frozen_string_literal: true

FactoryBot.define do
  factory :remote_development_namespace_cluster_agent_mapping,
    class: 'RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping' do
    user factory: [:user]
    agent factory: [:cluster_agent, :in_group]
    namespace { agent.project.namespace }
  end
end
