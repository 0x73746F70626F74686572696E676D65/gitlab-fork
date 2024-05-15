# frozen_string_literal: true

module EE
  module Clusters
    module AgentPolicy
      extend ActiveSupport::Concern

      prepended do
        rule { can?(:owner_access) }.enable :admin_remote_development_cluster_agent_mapping
      end
    end
  end
end
