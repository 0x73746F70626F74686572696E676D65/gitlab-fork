# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::SecurityPolicies::ScanResultPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:framework) { create(:compliance_framework) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let_it_be(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
  let_it_be(:policy) { build(:scan_result_policy, name: 'Enforce approvals', policy_scope: policy_scope) }

  describe '#resolve' do
    subject(:resolve_policies) do
      sync(resolve(described_class, obj: framework, args: {}, ctx: { current_user: current_user }))
    end

    context 'when user is unauthorized' do
      it 'returns nil' do
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
              project, id: CGI.escape(policy[:name]), type: 'approval_policy'
            ),
            enabled: policy[:enabled],
            policy_scope: {
              compliance_frameworks: [framework],
              including_projects: [],
              excluding_projects: []
            },
            yaml: YAML.dump(policy.deep_stringify_keys),
            updated_at: policy_configuration.policy_last_updated_at,
            user_approvers: [],
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

      before_all do
        project.add_owner(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        stub_feature_flags(security_policies_breaking_changes: false)

        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return({ scan_result_policy: [policy] }.to_yaml)
        end
      end

      it 'returns the policy' do
        expect(resolve_policies).to match_array(expected_response)
      end

      context 'when the feature flag security_policies_breaking_changes is enabled' do
        before do
          stub_feature_flags(security_policies_breaking_changes: true)
        end

        let(:expected_response) do
          [
            {
              name: policy[:name],
              description: policy[:description],
              edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
                project, id: CGI.escape(policy[:name]), type: 'approval_policy'
              ),
              enabled: policy[:enabled],
              policy_scope: {
                compliance_frameworks: [framework],
                including_projects: [],
                excluding_projects: []
              },
              yaml: YAML.dump(policy.deep_stringify_keys),
              updated_at: policy_configuration.policy_last_updated_at,
              user_approvers: [],
              all_group_approvers: [],
              deprecated_properties: [],
              role_approvers: [],
              source: {
                inherited: false,
                namespace: nil,
                project: project
              }
            }
          ]
        end

        it 'returns the policy' do
          expect(resolve_policies).to match_array(expected_response)
        end
      end
    end
  end
end
