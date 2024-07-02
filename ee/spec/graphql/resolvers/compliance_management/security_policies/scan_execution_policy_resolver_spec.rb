# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::SecurityPolicies::ScanExecutionPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:framework) { create(:compliance_framework) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let_it_be(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
  let_it_be(:policy) { build(:scan_execution_policy, name: 'Run DAST in every pipeline', policy_scope: policy_scope) }

  describe '#resolve' do
    subject(:resolve_policies) do
      sync(resolve(described_class, obj: framework, args: {}, ctx: { current_user: current_user }))
    end

    context 'when user is unauthorized' do
      it 'returns an empty array' do
        expect(resolve_policies).to be_empty
      end
    end

    context 'when user is authorized' do
      let(:merged_policy) do
        policy.merge({
          config: policy_configuration,
          project: project,
          namespace: nil,
          inherited: false
        })
      end

      let(:expected_response) do
        [
          {
            name: policy[:name],
            description: policy[:description],
            edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
              project, id: CGI.escape(policy[:name]), type: 'scan_execution_policy'
            ),
            enabled: policy[:enabled],
            policy_scope: {
              compliance_frameworks: [framework],
              including_projects: [],
              excluding_projects: [],
              including_groups: [],
              excluding_groups: []
            },
            yaml: YAML.dump(policy.deep_stringify_keys),
            updated_at: policy_configuration.policy_last_updated_at,
            source: {
              project: project,
              namespace: nil,
              inherited: false
            }
          }
        ]
      end

      before_all do
        project.add_owner(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return({ scan_execution_policy: [policy] }.to_yaml)
        end
      end

      it 'returns the policy' do
        expect(resolve_policies).to match_array(expected_response)
      end
    end
  end

  def edit_project_policy_path(target_project, policy)
    Gitlab::Routing.url_helpers.edit_project_security_policy_url(
      target_project, id: CGI.escape(policy[:name]), type: 'scan_execution_policy'
    )
  end
end
