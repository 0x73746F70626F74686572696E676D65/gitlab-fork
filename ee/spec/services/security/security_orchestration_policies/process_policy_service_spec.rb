# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ProcessPolicyService, feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

    let(:policy) { build(:scan_execution_policy, name: 'Test Policy', enabled: false) }
    let(:scheduled_policy) { build(:scan_execution_policy, :with_schedule, name: 'Scheduled DAST') }
    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(policy.to_yaml).load! }
    let(:type) { :scan_execution_policy }
    let(:operation) { :append }
    let(:policy_name) { policy[:name] }

    let(:repository_with_existing_policy_yaml) do
      pipeline_policy = build(:scan_execution_policy, name: 'Test Policy')
      build(:orchestration_policy_yaml, scan_execution_policy: [pipeline_policy, scheduled_policy])
    end

    let(:repository_policy_yaml) do
      pipeline_policy = build(:scan_execution_policy, name: "Execute DAST in every pipeline")
      build(:orchestration_policy_yaml, scan_execution_policy: [pipeline_policy, scheduled_policy])
    end

    subject(:service) { described_class.new(policy_configuration: policy_configuration, params: { policy: policy_yaml, name: policy_name, operation: operation, type: type }) }

    context 'when policy is invalid' do
      let(:policy_name) { 'invalid' }
      let(:policy) { { name: 'invalid', invalid_field: 'invalid' } }

      it 'returns error' do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('Invalid policy YAML')
        expect(result[:details]).to eq(["property '/scan_execution_policy/0' is missing required keys: enabled, rules, actions"])
      end
    end

    context 'when policy name is not same as in policy' do
      let(:policy_name) { 'invalid' }

      it 'returns error' do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('Name should be same as the policy name')
      end
    end

    context 'append policy' do
      context 'when policy is present in repository' do
        before do
          allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(repository_policy_yaml).load!)
        end

        it 'appends the new policy' do
          result = service.execute

          expect(result[:status]).to eq(:success)
          expect(result.dig(:policy_hash, :scan_execution_policy).count).to eq(3)
        end
      end

      context 'when policy with same name already exists in repository' do
        before do
          allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(repository_with_existing_policy_yaml).load!)
        end

        it 'returns error' do
          result = service.execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq('Policy already exists with same name')
        end
      end

      context 'when policy with same name exists as scan_result_policy and type specifies approval policy' do
        let(:type) { :approval_policy }
        let(:policy) { build(:approval_policy, name: 'Test Policy', enabled: false) }
        let(:policies_yaml) do
          build(:orchestration_policy_yaml, scan_result_policy: [build(:scan_result_policy, name: "Test Policy")])
        end

        before do
          allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(policies_yaml).load!)
        end

        it 'returns error' do
          result = service.execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq('Policy already exists with same name')
        end
      end

      context 'when policy with same name exists as approval_policy and type specifies scan_result_policy' do
        let(:type) { :scan_result_policy }
        let(:policy) { build(:scan_result_policy, name: 'Test Policy', enabled: false) }
        let(:policies_yaml) do
          build(:orchestration_policy_yaml, approval_policy: [build(:approval_policy, name: "Test Policy")])
        end

        before do
          allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(policies_yaml).load!)
        end

        it 'returns error' do
          result = service.execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq('Policy already exists with same name')
        end
      end

      context 'when policy is not present in repository' do
        before do
          allow(policy_configuration).to receive(:policy_hash).and_return(nil)
        end

        it 'appends the new policy' do
          result = service.execute

          expect(result[:status]).to eq(:success)
          expect(result.dig(:policy_hash, :scan_execution_policy).count).to eq(1)
        end
      end
    end

    context 'replace policy' do
      let(:operation) { :replace }
      let(:policies_yaml) { repository_with_existing_policy_yaml }

      before do
        allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(policies_yaml).load!)
      end

      context 'when policy is not present in repository' do
        let(:policies_yaml) { repository_policy_yaml }

        it 'returns error' do
          result = service.execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq('Policy does not exist')
        end
      end

      context 'when policy name is empty' do
        let(:policy_name) { nil }

        it 'does not modify the policy name' do
          result = service.execute

          expect(result.dig(:policy_hash, :scan_execution_policy).first).to eq(policy_yaml)
        end
      end

      context 'when policy with same name already exists in repository' do
        it 'replaces the policy' do
          result = service.execute

          expect(result.dig(:policy_hash, :scan_execution_policy).first[:enabled]).to be_falsey
        end
      end

      describe 'mixed scan_result_policy and approval_policy types' do
        context 'when policy with the same name exists as "scan_result_policy" and type specifies "approval_policy"' do
          let(:type) { :approval_policy }
          let(:policy) { build(:scan_result_policy, name: 'Test Policy', enabled: false) }
          let(:policies_yaml) do
            build(:orchestration_policy_yaml, scan_result_policy: [build(:scan_result_policy, name: "Test Policy")])
          end

          it 'replaces the policy and migrates it to `approval_policy` type' do
            result = service.execute
            policy = result.dig(:policy_hash, :approval_policy).first

            expect(result.dig(:policy_hash, :scan_result_policy)).to eq([])
            expect(policy[:name]).to eq('Test Policy')
            expect(policy[:enabled]).to be_falsey
          end
        end

        context 'when policy with the same name exists as "approval_policy" and type specifies "scan_result_policy"' do
          let(:type) { :scan_result_policy }
          let(:policy) { build(:approval_policy, name: 'Test Policy', enabled: false) }
          let(:policies_yaml) do
            build(:orchestration_policy_yaml, approval_policy: [build(:approval_policy, name: "Test Policy")])
          end

          it 'replaces the policy' do
            result = service.execute

            expect(result.dig(:policy_hash, :approval_policy).first[:enabled]).to be_falsey
          end
        end
      end

      context 'when policy name is not same as in policy' do
        let(:policy_yaml) do
          Gitlab::Config::Loader::Yaml.new(build(:scan_execution_policy, name: 'Updated Policy', enabled: false).to_yaml).load!
        end

        it 'updates the policy name' do
          result = service.execute

          expect(result.dig(:policy_hash, :scan_execution_policy).first[:name]).to eq('Updated Policy')
        end
      end

      context 'when name of the policy to be updated already exists' do
        let(:policy_yaml) do
          Gitlab::Config::Loader::Yaml.new(build(:scan_execution_policy, name: 'Scheduled DAST', enabled: false).to_yaml).load!
        end

        it 'returns error' do
          result = service.execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq('Policy already exists with same name')
        end
      end
    end

    context 'remove policy' do
      let(:operation) { :remove }

      context 'when policy is not present in repository' do
        before do
          allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(repository_policy_yaml).load!)
        end

        it 'returns error' do
          result = service.execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq('Policy does not exist')
        end
      end

      context 'when policy with same name already exists in repository' do
        let(:policies_yaml) { repository_with_existing_policy_yaml }

        before do
          allow(policy_configuration).to receive(:policy_hash).and_return(Gitlab::Config::Loader::Yaml.new(policies_yaml).load!)
        end

        it 'removes the policy' do
          result = service.execute

          expect(result[:status]).to eq(:success)
          expect(result.dig(:policy_hash, :scan_execution_policy).count).to eq(1)
        end

        describe 'mixed scan_result_policy and approval_policy types' do
          context 'when policy exists as "scan_result_policy" and type specifies "approval_policy"' do
            let(:type) { :approval_policy }
            let(:policy) { build(:scan_result_policy, name: 'Test Policy') }
            let(:policies_yaml) do
              build(:orchestration_policy_yaml, scan_result_policy: [build(:scan_result_policy, name: 'Test Policy')])
            end

            it 'removes the policy' do
              result = service.execute

              expect(result.dig(:policy_hash, :scan_result_policy)).to eq([])
            end
          end

          context 'when policy exists as "approval_policy" and type specifies "scan_result_policy"' do
            let(:type) { :scan_result_policy }
            let(:policy) { build(:approval_policy, name: 'Test Policy') }
            let(:policies_yaml) do
              build(:orchestration_policy_yaml, approval_policy: [build(:approval_policy, name: 'Test Policy')])
            end

            it 'removes the policy' do
              result = service.execute

              expect(result.dig(:policy_hash, :approval_policy)).to eq([])
            end
          end
        end
      end
    end
  end
end
