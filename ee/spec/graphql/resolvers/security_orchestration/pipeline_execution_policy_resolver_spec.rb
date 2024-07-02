# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecurityOrchestration::PipelineExecutionPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  include_context 'orchestration policy context'

  let(:policy) { build(:pipeline_execution_policy, name: 'Run custom pipeline') }
  let(:policy_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: [policy]) }
  let(:expected_resolved) do
    [
      {
        name: 'Run custom pipeline',
        description: 'This policy enforces execution of custom CI in the pipeline',
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(policy[:name]), type: 'pipeline_execution_policy'
        ),
        enabled: true,
        policy_scope: {
          compliance_frameworks: [],
          including_projects: [],
          excluding_projects: [],
          including_groups: [],
          excluding_groups: []
        },
        yaml: YAML.dump(policy.deep_stringify_keys),
        updated_at: policy_last_updated_at,
        source: {
          inherited: false,
          namespace: nil,
          project: project
        }
      }
    ]
  end

  subject(:resolve_scan_policies) { resolve(described_class, obj: project, ctx: { current_user: user }) }

  it_behaves_like 'as an orchestration policy'
end
