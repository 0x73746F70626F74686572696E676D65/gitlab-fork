# frozen_string_literal: true

module Security
  class ScanResultPolicyRead < ApplicationRecord
    include EachBatch

    self.table_name = 'scan_result_policies'

    enum age_operator: { greater_than: 0, less_than: 1 }
    enum age_interval: { day: 0, week: 1, month: 2, year: 3 }

    belongs_to :security_orchestration_policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration'
    belongs_to :project, optional: true
    has_many :software_license_policies

    validates :match_on_inclusion, inclusion: { in: [true, false], message: 'must be a boolean value' }
    validates :role_approvers, inclusion: { in: Gitlab::Access.all_values }
    validates :age_value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :vulnerability_attributes, json_schema: { filename: 'scan_result_policy_vulnerability_attributes' },
      allow_blank: true

    def newly_detected?
      license_states.include?(ApprovalProjectRule::NEWLY_DETECTED)
    end
  end
end
