# frozen_string_literal: true

module RemoteDevelopment
  module AgentPolicy
    extend ActiveSupport::Concern

    included do
      rule { admin | can?(:owner_access) }.enable :admin_remote_development_cluster_agent_mapping
    end
  end
end
