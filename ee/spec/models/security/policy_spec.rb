# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policy, feature_category: :security_policy_management do
  subject(:policy) { create(:security_policy, :require_approval) }

  describe 'associations' do
    it { is_expected.to belong_to(:security_orchestration_policy_configuration) }
    it { is_expected.to have_many(:approval_policy_rules) }

    it do
      is_expected.to validate_uniqueness_of(:security_orchestration_policy_configuration_id).scoped_to(%i[type
        policy_index])
    end
  end

  describe 'validations' do
    describe 'scope' do
      it { is_expected.to be_valid }

      context 'with empty scope' do
        before do
          policy.scope = {}
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid scope' do
        before do
          policy.scope = { foo: "bar" }
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'actions' do
      it { is_expected.to be_valid }

      context 'without actions' do
        before do
          policy.actions = []
        end

        it { is_expected.to be_invalid }
      end

      context 'with invalid actions' do
        before do
          policy.actions.push(foo: "bar")
        end

        it { is_expected.to be_invalid }
      end
    end

    describe 'approval_settings' do
      it { is_expected.to be_valid }

      context 'with empty approval settings' do
        before do
          policy.approval_settings = {}
        end

        it { is_expected.to be_valid }
      end

      context 'with invalid approval settings' do
        before do
          policy.approval_settings[:foo] = "bar"
        end

        it { is_expected.to be_invalid }
      end
    end
  end

  describe '.upsert_policy' do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let(:policies) { policy_configuration.security_policies }
    let(:policy_hash) { build(:scan_result_policy, name: "foobar") }
    let(:policy_index) { 0 }

    subject(:upsert!) { described_class.upsert_policy(policies, policy_hash, policy_index) }

    context 'when the policy does not exist' do
      let(:upserted_policy) { policy_configuration.security_policies.last }

      it 'creates a new policy' do
        expect { upsert! }.to change { policies.count }.by(1)
        expect(upserted_policy.name).to eq(policy_hash[:name])
        expect(upserted_policy.approval_policy_rules.count).to be(1)
      end
    end

    context 'with existing policy' do
      let!(:existing_policy) do
        create(:security_policy,
          security_orchestration_policy_configuration: policy_configuration,
          policy_index: policy_index)
      end

      let(:upserted_policy) { existing_policy.reload }

      it 'updates the policy' do
        expect { upsert! }.not_to change { policies.count }
        expect(upserted_policy).to eq(existing_policy)
        expect(upserted_policy.name).to eq(policy_hash[:name])
        expect(upserted_policy.approval_policy_rules.count).to be(1)
      end
    end
  end

  describe '.delete_by_ids' do
    let_it_be(:policies) { create_list(:security_policy, 3) }

    subject(:delete!) { described_class.delete_by_ids(policies.first(2).pluck(:id)) }

    it 'deletes by ID' do
      expect { delete! }.to change { described_class.all }.to(contain_exactly(policies.last))
    end
  end
end
