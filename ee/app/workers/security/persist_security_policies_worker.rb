# frozen_string_literal: true

module Security
  class PersistSecurityPoliciesWorker
    include ApplicationWorker

    data_consistency :sticky
    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    feature_category :security_policy_management

    def perform(configuration_id)
      configuration = Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id) || return

      return unless configuration.persist_policies?

      configuration.invalidate_policy_yaml_cache

      Security::SecurityOrchestrationPolicies::PersistPolicyService
        .new(policy_configuration: configuration,
          policies: configuration.scan_result_policies,
          policy_type: :approval_policy)
        .execute

      Security::SecurityOrchestrationPolicies::PersistPolicyService
        .new(policy_configuration: configuration,
          policies: configuration.scan_execution_policy,
          policy_type: :scan_execution_policy)
        .execute
    end
  end
end
