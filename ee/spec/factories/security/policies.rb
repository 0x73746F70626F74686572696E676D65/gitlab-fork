# frozen_string_literal: true

FactoryBot.define do
  FactoryBot.define do
    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [
              { id: 1 }
            ],
            excluding: [
              { id: 2 }
            ]
          }
        }
      end
    end
  end

  factory :security_policy, class: 'Security::Policy' do
    security_orchestration_policy_configuration
    sequence(:name) { |n| "security-policy-#{n}" }
    checksum { Digest::SHA256.hexdigest(rand.to_s) }
    policy_index { 0 }
    type { Security::Policy.types[:approval_policy] }
    enabled { true }
    scope { {} }
    approval_settings { {} }
    security_policy_management_project_id do
      security_orchestration_policy_configuration.security_policy_management_project_id
    end
    require_approval

    trait :require_approval do
      actions { [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[owner] }] }
    end

    trait :scan_execution_policy do
      type { Security::Policy.types[:scan_execution_policy] }
    end
  end

  factory :scan_execution_policy, class: Struct.new(:name, :description, :enabled, :actions, :rules, :policy_scope) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      actions = attributes[:actions]
      rules = attributes[:rules]
      policy_scope = attributes[:policy_scope]

      new(name, description, enabled, actions, rules, policy_scope).to_h
    end

    transient do
      agent { 'agent-name' }
      namespaces { %w[namespace-a namespace-b] }
    end

    sequence(:name) { |n| "test-policy-#{n}" }
    description { 'This policy enforces to run DAST for every pipeline within the project' }
    enabled { true }
    rules { [{ type: 'pipeline', branches: %w[master] }] }
    actions { [{ scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }] }
    policy_scope { {} }

    trait :with_schedule do
      rules { [{ type: 'schedule', branches: %w[master], cadence: '*/15 * * * *' }] }
    end

    trait :with_schedule_and_agent do
      rules { [{ type: 'schedule', agents: { agent.name => { namespaces: namespaces } }, cadence: '30 2 * * *' }] }
      actions { [{ scan: 'container_scanning' }] }
    end
  end

  factory :pipeline_execution_policy,
    class: Struct.new(:name, :description, :enabled, :pipeline_config_strategy, :content, :policy_scope) do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      pipeline_config_strategy = attributes[:pipeline_config_strategy]
      content = attributes[:content]
      policy_scope = attributes[:policy_scope]

      new(name, description, enabled, pipeline_config_strategy, content, policy_scope).to_h
    end

    sequence(:name) { |n| "test-pipeline-execution-policy-#{n}" }
    description { 'This policy enforces execution of custom CI in the pipeline' }
    enabled { true }
    content { {} }
    pipeline_config_strategy { 'inject_ci' }
    policy_scope { {} }

    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [],
            excluding: []
          }
        }
      end
    end
  end

  factory :scan_result_policy,
    class: Struct.new(:name, :description, :enabled, :actions, :rules, :approval_settings, :policy_scope,
      :fallback_behavior),
    aliases: %i[approval_policy] do
    skip_create

    initialize_with do
      name = attributes[:name]
      description = attributes[:description]
      enabled = attributes[:enabled]
      actions = attributes[:actions]
      rules = attributes[:rules]
      approval_settings = attributes[:approval_settings]
      policy_scope = attributes[:policy_scope]
      fallback_behavior = attributes[:fallback_behavior]

      new(name, description, enabled, actions, rules, approval_settings, policy_scope, fallback_behavior).to_h
    end

    transient do
      branches { ['master'] }
      vulnerability_attributes { {} }
      commits { 'unsigned' }
    end

    sequence(:name) { |n| "test-policy-#{n}" }
    description { 'This policy considers only container scanning and critical severities' }
    enabled { true }
    rules do
      [
        {
          type: 'scan_finding',
          branches: branches,
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected],
          vulnerability_attributes: vulnerability_attributes
        }
      ]
    end

    actions { [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }] }
    approval_settings { {} }
    policy_scope { {} }
    fallback_behavior { {} }

    trait :license_finding do
      rules do
        [
          {
            type: 'license_finding',
            branches: branches,
            match_on_inclusion_license: true,
            license_types: %w[BSD MIT],
            license_states: %w[newly_detected detected]
          }
        ]
      end
    end

    trait :any_merge_request do
      rules do
        [
          {
            type: 'any_merge_request',
            branches: branches,
            commits: commits
          }
        ]
      end
    end

    trait :with_approval_settings do
      approval_settings do
        {
          prevent_approval_by_author: true,
          prevent_approval_by_commit_author: true,
          remove_approvals_with_new_commit: true,
          require_password_to_approve: true,
          block_branch_modification: true,
          prevent_pushing_and_force_pushing: true
        }
      end
    end

    trait :with_policy_scope do
      policy_scope do
        {
          compliance_frameworks: [
            { id: 1 },
            { id: 2 }
          ],
          projects: {
            including: [
              { id: 1 }
            ],
            excluding: [
              { id: 2 }
            ]
          }
        }
      end
    end

    trait :with_disabled_bot_message do
      actions do
        [
          { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] },
          { type: 'send_bot_message', enabled: false }
        ]
      end
    end

    trait :fail_open do
      fallback_behavior { { fail: "open" } }
    end
  end

  factory :orchestration_policy_yaml,
    class: Struct.new(:scan_execution_policy, :scan_result_policy, :approval_policy, :pipeline_execution_policy) do
    skip_create

    initialize_with do
      scan_execution_policy = attributes[:scan_execution_policy]
      scan_result_policy = attributes[:scan_result_policy]
      approval_policy = attributes[:approval_policy]
      pipeline_execution_policy = attributes[:pipeline_execution_policy]

      YAML.dump(
        new(
          scan_execution_policy,
          scan_result_policy,
          approval_policy,
          pipeline_execution_policy
        ).to_h.compact.deep_stringify_keys
      )
    end
  end
end
