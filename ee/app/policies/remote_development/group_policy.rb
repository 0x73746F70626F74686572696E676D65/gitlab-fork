# frozen_string_literal: true

module RemoteDevelopment
  module GroupPolicy
    extend ActiveSupport::Concern

    included do
      rule { owner | admin }.enable :admin_remote_development_cluster_agent_mapping
    end
  end
end
