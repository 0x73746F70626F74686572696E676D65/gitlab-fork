# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecurityOrchestration::ScanResultPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  include_context 'orchestration policy context'

  let(:policy) { build(:scan_result_policy, name: 'Require security approvals') }
  let(:policy_yaml) { build(:orchestration_policy_yaml, scan_result_policy: [policy]) }
  let(:expected_resolved) do
    [
      {
        name: 'Require security approvals',
        description: 'This policy considers only container scanning and critical severities',
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(policy[:name]), type: 'approval_policy'
        ),
        enabled: true,
        policy_scope: nil,
        yaml: YAML.dump(policy.deep_stringify_keys),
        updated_at: policy_last_updated_at,
        user_approvers: [],
        group_approvers: [],
        all_group_approvers: [],
        role_approvers: [],
        source: {
          inherited: false,
          namespace: nil,
          project: project
        }
      }
    ]
  end

  subject(:resolve_scan_policies) { resolve(described_class, obj: project, ctx: { current_user: user }) }

  before do
    stub_feature_flags(security_policies_breaking_changes: false)
  end

  it_behaves_like 'as an orchestration policy'

  context 'when the feature flag security_policies_breaking_changes is enabled' do
    before do
      stub_feature_flags(security_policies_breaking_changes: true)
    end

    let(:deprecated_properties) { [] }

    let(:expected_resolved) do
      [
        {
          name: 'Require security approvals',
          description: 'This policy considers only container scanning and critical severities',
          edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
            project, id: CGI.escape(policy[:name]), type: 'approval_policy'
          ),
          enabled: true,
          policy_scope: nil,
          yaml: YAML.dump(policy.deep_stringify_keys),
          updated_at: policy_last_updated_at,
          user_approvers: [],
          group_approvers: [],
          all_group_approvers: [],
          deprecated_properties: deprecated_properties,
          role_approvers: [],
          source: {
            inherited: false,
            namespace: nil,
            project: project
          }
        }
      ]
    end

    it_behaves_like 'as an orchestration policy'

    context 'when the policy contains deprecated properties' do
      let(:policy) { build(:scan_result_policy, name: 'Require security approvals', rules: [rule]) }

      let(:rule) do
        {
          type: 'license_finding',
          branches: %w[master],
          match_on_inclusion_license: true,
          license_types: %w[BSD MIT],
          license_states: %w[newly_detected]
        }
      end

      let(:deprecated_properties) { ['newly_detected'] }

      it_behaves_like 'as an orchestration policy'
    end
  end
end
