# frozen_string_literal: true

module Security
  class ApprovalPolicyRule < ApplicationRecord
    include PolicyRule

    self.table_name = 'approval_policy_rules'

    enum type: { scan_finding: 0, license_finding: 1, any_merge_request: 2 }, _prefix: true

    belongs_to :security_policy, class_name: 'Security::Policy', inverse_of: :approval_policy_rules

    validates :typed_content, json_schema: { filename: "approval_policy_rule_content" }
  end
end
