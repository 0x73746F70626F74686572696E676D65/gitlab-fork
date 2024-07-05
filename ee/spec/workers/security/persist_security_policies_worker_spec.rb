# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PersistSecurityPoliciesWorker, '#perform', feature_category: :security_policy_management do
  include_context 'with scan result policy' do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration) }

    let(:policy_yaml) do
      build(
        :orchestration_policy_yaml,
        scan_execution_policy: scan_execution_policies,
        scan_result_policy: scan_result_policies)
    end

    let(:scan_result_policies) { build_list(:scan_result_policy, 2) + [build(:scan_result_policy, active: false)] }
    let(:scan_execution_policies) do
      build_list(:scan_execution_policy, 2) + [build(:scan_execution_policy, active: false)]
    end

    it_behaves_like 'an idempotent worker' do
      subject(:perform) { perform_multiple(policy_configuration.id) }

      describe 'cache eviction' do
        let(:config) { spy }

        before do
          allow(Security::OrchestrationPolicyConfiguration)
            .to receive(:find_by_id).with(policy_configuration.id).and_return(config)

          allow(Gitlab::AppJsonLogger).to receive(:debug)
        end

        it 'evicts policy cache' do
          perform

          expect(config).to have_received(:invalidate_policy_yaml_cache).at_least(:once)
        end
      end

      it 'persists approval policies' do
        perform

        expect(policy_configuration.security_policies.type_approval_policy.count).to be(3)
      end

      it 'persists scan execution policies' do
        perform

        expect(policy_configuration.security_policies.type_scan_execution_policy.count).to be(3)
      end

      context 'with feature disabled' do
        before do
          stub_feature_flags(security_policies_sync: false)
        end

        it 'does not persist policies' do
          expect { perform }.not_to change { policy_configuration.security_policies.count }
        end
      end
    end
  end
end
