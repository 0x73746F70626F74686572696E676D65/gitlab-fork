# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Aggregations::SecurityOrchestrationPolicies::LazyComplianceFrameworkAggregate, feature_category: :security_policy_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: current_user) }
  let_it_be_with_reload(:framework) { create(:compliance_framework) }
  let_it_be_with_reload(:other_framework) { create(:compliance_framework) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be_with_reload(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let(:policy_type) { :scan_result_policies }
  let(:query_ctx) { { current_user: current_user } }

  subject(:lazy_aggregate) { described_class.new(query_ctx, framework, policy_type) }

  describe '#initialize' do
    it 'adds the frameworks to the lazy state' do
      expect(lazy_aggregate.lazy_state[:pending_frameworks]).to eq [framework]
      expect(lazy_aggregate.object).to eq framework
    end

    context 'when there is pending_framework' do
      let(:query_ctx) do
        {
          lazy_compliance_framework_in_policies_aggregate: {
            pending_frameworks: [other_framework],
            loaded_objects: {}
          }
        }
      end

      it 'uses lazy_compliance_framework_in_policies_aggregate to collect aggregates' do
        expect(lazy_aggregate.lazy_state[:pending_frameworks]).to match_array [other_framework, framework]
        expect(lazy_aggregate.object).to eq framework
      end
    end
  end

  describe '#execute' do
    let(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
    let(:scan_execution_policy) do
      build(:scan_execution_policy, name: 'SEP 1', policy_scope: policy_scope)
    end

    let(:scan_result_policy) do
      build(:scan_result_policy, name: 'SRP 1', policy_scope: policy_scope)
    end

    let(:policy_yaml) do
      build(:orchestration_policy_yaml,
        scan_execution_policy: [scan_execution_policy],
        scan_result_policy: [scan_result_policy]
      )
    end

    before do
      stub_licensed_features(security_orchestration_policies: true)
      lazy_aggregate.instance_variable_set(:@lazy_state, fake_state)

      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      end
    end

    context 'when the record is already been loaded' do
      let(:fake_state) do
        {
          pending_frameworks: [],
          loaded_objects: { framework.id => { scan_result_policies: [], scan_execution_policies: [] } }
        }
      end

      it 'does not call the finder' do
        expect(::Security::SecurityPoliciesFinder).not_to receive(:new)

        lazy_aggregate.execute
      end
    end

    context 'when the record is not loaded' do
      let(:fake_state) do
        { pending_frameworks: Set.new([framework, other_framework]), loaded_objects: {} }
      end

      it 'makes the query' do
        policies = lazy_aggregate.execute

        expect(policies.count).to eq(1)
        expect(policies[0][:name]).to eq(scan_result_policy[:name])
      end

      it 'clears the pending frameworks' do
        lazy_aggregate.execute

        expect(lazy_aggregate.lazy_state[:pending_frameworks]).to be_empty
      end

      context 'when policy is not scoped to the loaded framework' do
        let(:policy_scope) { { compliance_frameworks: [{ id: other_framework.id }] } }

        it 'does not return policies' do
          policies = lazy_aggregate.execute

          expect(policies.count).to eq(0)
        end
      end

      context 'when policy_scope is empty' do
        let(:policy_scope) { {} }

        it 'does not return policies' do
          policies = lazy_aggregate.execute

          expect(policies.count).to eq(0)
        end
      end
    end
  end
end
