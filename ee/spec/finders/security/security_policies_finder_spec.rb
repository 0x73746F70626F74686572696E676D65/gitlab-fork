# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityPoliciesFinder, feature_category: :security_policy_management do
  let_it_be(:scan_result_policy) { build(:scan_result_policy, name: 'SRP 1') }
  let_it_be(:scan_execution_policy) { build(:scan_execution_policy, name: 'SEP 1') }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:actor) { create(:user, developer_of: [project, group]) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

  let_it_be(:group_policy_configuration) do
    create(:security_orchestration_policy_configuration, :namespace, namespace: group)
  end

  subject { described_class.new(actor, [policy_configuration, group_policy_configuration]).execute }

  describe '#execute' do
    context 'when feature is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'returns empty collection' do
        is_expected.to eq({ scan_execution_policies: [], scan_result_policies: [] })
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)

        allow(policy_configuration).to receive(:scan_result_policies).and_return([scan_result_policy])
        allow(policy_configuration).to receive(:scan_execution_policy).and_return([])
        allow(group_policy_configuration).to receive(:scan_result_policies).and_return([])
        allow(group_policy_configuration).to receive(:scan_execution_policy).and_return([scan_execution_policy])
      end

      context 'when configuration is associated to project' do
        it 'returns policies with project' do
          is_expected.to eq({ scan_result_policies: [scan_result_policy.merge({
            config: policy_configuration,
            project: project,
            namespace: nil,
            inherited: false
          })], scan_execution_policies: [scan_execution_policy.merge({
            config: group_policy_configuration,
            project: nil,
            namespace: group,
            inherited: false
          })] })
        end
      end

      context 'when user is unauthorized' do
        let_it_be(:actor) { create(:user) }

        it 'returns empty collection' do
          is_expected.to eq({ scan_execution_policies: [], scan_result_policies: [] })
        end
      end
    end
  end
end
