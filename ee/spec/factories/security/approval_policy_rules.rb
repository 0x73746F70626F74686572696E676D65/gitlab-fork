# frozen_string_literal: true

FactoryBot.define do
  factory :approval_policy_rule, class: 'Security::ApprovalPolicyRule' do
    security_policy
    sequence(:rule_index)
    security_policy_management_project_id do
      security_policy.security_orchestration_policy_configuration.security_policy_management_project_id
    end
    scan_finding

    trait :scan_finding do
      type { Security::ApprovalPolicyRule.types[:scan_finding] }
      content do
        {
          type: 'scan_finding',
          branches: [],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected]
        }
      end
    end

    trait :license_finding do
      type { Security::ApprovalPolicyRule.types[:license_finding] }
      content do
        {
          type: 'license_finding',
          branches: [],
          match_on_inclusion_license: true,
          license_types: %w[BSD MIT],
          license_states: %w[newly_detected detected]
        }
      end
    end

    trait :any_merge_request do
      type { Security::ApprovalPolicyRule.types[:any_merge_request] }
      content do
        {
          type: 'any_merge_request',
          branches: [],
          commits: 'any'
        }
      end
    end
  end
end
