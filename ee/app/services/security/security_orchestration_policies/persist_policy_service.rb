# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PersistPolicyService
      include BaseServiceUtility
      include Gitlab::Loggable

      def initialize(policy_configuration:, policies:, policy_type:)
        @policy_configuration = policy_configuration
        @policies = policies

        @policy_type = case policy_type
                       when :approval_policy, :scan_result_policy then :approval_policy
                       when :scan_execution_policy then :scan_execution_policy
                       else raise ArgumentError, "unrecognized policy_type"
                       end
      end

      def execute
        Gitlab::AppJsonLogger.debug(
          build_structured_payload(
            security_orchestration_policy_configuration_id: policy_configuration.id,
            policies: policies))

        existing_policies = policy_configuration.security_policies.merge(relation_scope)
        existing_policies_with_checksums = existing_policies.index_with(&:checksum)
        new_policies, outdated_policies, updated_policies = categorize_policies(existing_policies_with_checksums)

        ApplicationRecord.transaction do
          delete_outdated_policies(outdated_policies)
          create_new_policies(new_policies)
          update_rearranged_policies(updated_policies)
        end

        success
      rescue StandardError => e
        error(e.message)
      end

      private

      attr_reader :policy_configuration, :policies, :policy_type

      delegate :security_policies, to: :policy_configuration

      def categorize_policies(existing_policies_with_checksums)
        outdated_policies = existing_policies_with_checksums.keys
        new_policies = []
        updated_policies = []

        policies.each_with_index do |policy_hash, index|
          checksum = Security::Policy.checksum(policy_hash)
          existing_policy = existing_policies_with_checksums.key(checksum)

          # If the policy doesn't exist yet, create it
          next new_policies << [policy_hash, index] unless existing_policy

          # Policy exists. If the policy index has changed, update the index, otherwise no-op
          outdated_policies.delete(existing_policy)
          updated_policies << [existing_policy, index] if existing_policy.policy_index != index
        end

        [new_policies, outdated_policies, updated_policies]
      end

      def create_new_policies(new_policies)
        new_policies.each do |policy_hash, index|
          upsert_policy(policy_hash, index)
        end
      end

      def delete_outdated_policies(outdated_policies)
        # rubocop:disable CodeReuse/ActiveRecord -- plucking array of records
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- policy count is limited
        Security::Policy.delete_by_ids(outdated_policies.pluck(:id))
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit
        # rubocop:enable CodeReuse/ActiveRecord
      end

      # Updates in two steps to avoid unique constraint violations
      def update_rearranged_policies(updated_policies)
        updated_policies.each_with_index do |(policy, _), temp_index|
          policy.update!(policy_index: -1 - temp_index) # assign a negative temporary index
        end

        updated_policies.each do |policy, new_index|
          policy.update!(policy_index: new_index)
        end
      end

      def upsert_policy(policy_hash, policy_index)
        Security::Policy.upsert_policy(policy_type, security_policies, policy_hash, policy_index, policy_configuration)
      end

      def relation_scope
        case policy_type
        when :approval_policy then Security::Policy.type_approval_policy
        when :scan_execution_policy then Security::Policy.type_scan_execution_policy
        end
      end
    end
  end
end
