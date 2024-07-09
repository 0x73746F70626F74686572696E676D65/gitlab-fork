# frozen_string_literal: true

module Security
  module CiComponentSourcesPolicy
    POLICY_LIMIT = 5

    def active_ci_component_sources_policies
      ci_component_sources_policy.select { |config| config[:enabled] }.first(POLICY_LIMIT)
    end

    def ci_component_sources_policy
      policy_by_type(:ci_component_sources_policy)
    end
  end
end
