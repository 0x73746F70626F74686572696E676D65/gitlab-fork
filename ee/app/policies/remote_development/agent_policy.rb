# frozen_string_literal: true

module RemoteDevelopment
  module AgentPolicy
    extend ActiveSupport::Concern

    included do
      rule { can?(:owner_access) }.enable :admin_remote_development_cluster_agent_mapping
      rule { can?(:maintainer_access) }.enable :read_remote_development_cluster_agent_mapping
    end
  end
end
