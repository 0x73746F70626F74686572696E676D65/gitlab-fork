# frozen_string_literal: true

module Security
  class ApprovalPolicyRule < ApplicationRecord
    self.table_name = 'approval_policy_rules'
    self.inheritance_column = :_type_disabled

    enum type: { scan_finding: 0, license_finding: 1, any_merge_request: 2 }, _prefix: true

    belongs_to :security_policy, class_name: 'Security::Policy', inverse_of: :approval_policy_rules

    validates :typed_content, json_schema: { filename: "approval_policy_rule_content" }

    def self.attributes_from_rule_hash(rule_hash, policy_configuration)
      {
        type: rule_hash[:type],
        content: rule_hash.without(:type),
        security_policy_management_project_id: policy_configuration.security_policy_management_project_id
      }
    end

    def typed_content
      content.deep_stringify_keys.merge("type" => type)
    end
  end
end
