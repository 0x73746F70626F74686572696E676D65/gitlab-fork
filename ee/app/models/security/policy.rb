# frozen_string_literal: true

module Security
  class Policy < ApplicationRecord
    self.table_name = 'security_policies'
    self.inheritance_column = :_type_disabled

    belongs_to :security_orchestration_policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration'
    has_many :approval_policy_rules, class_name: 'Security::ApprovalPolicyRule', foreign_key: 'security_policy_id',
      inverse_of: :security_policy

    enum type: { approval_policy: 0, scan_execution_policy: 1 }, _prefix: true

    validates :security_orchestration_policy_configuration_id,
      uniqueness: { scope: %i[type policy_index] }

    validates :scope, json_schema: { filename: "security_policy_scope" }
    validates :scope, exclusion: { in: [nil] }

    validates :actions, json_schema: { filename: "security_policy_actions" }
    validates :actions, exclusion: { in: [nil] }

    validates :approval_settings, json_schema: { filename: "security_policy_approval_settings" }
    validates :approval_settings, exclusion: { in: [nil] }

    def self.checksum(policy_hash)
      Digest::SHA256.hexdigest(policy_hash.to_json)
    end

    def self.attributes_from_policy_hash(policy_hash, policy_configuration)
      {
        type: :approval_policy,
        name: policy_hash[:name],
        description: policy_hash[:description],
        enabled: policy_hash[:enabled],
        actions: policy_hash[:actions],
        approval_settings: policy_hash[:approval_settings],
        scope: policy_hash.fetch(:policy_scope, {}),
        checksum: checksum(policy_hash),
        security_policy_management_project_id: policy_configuration.security_policy_management_project_id
      }
    end

    def self.upsert_policy(policies, policy_hash, policy_index, policy_configuration, policy_type: :approval_policy)
      transaction do
        policy = policies.find_or_initialize_by(policy_index: policy_index, type: policy_type)
        policy.update!(attributes_from_policy_hash(policy_hash, policy_configuration))

        policy_hash[:rules].map.with_index do |rule_hash, rule_index|
          Security::ApprovalPolicyRule
            .find_or_initialize_by(security_policy_id: policy.id, rule_index: rule_index)
            .update!(Security::ApprovalPolicyRule.attributes_from_rule_hash(rule_hash, policy_configuration))
        end
      end
    end

    def self.delete_by_ids(ids)
      id_in(ids).delete_all
    end
  end
end
