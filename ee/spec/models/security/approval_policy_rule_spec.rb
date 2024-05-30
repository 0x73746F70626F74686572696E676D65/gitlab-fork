# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ApprovalPolicyRule, feature_category: :security_policy_management do
  it_behaves_like 'policy rule' do
    let(:rule_hash) { build(:scan_result_policy)[:rules].first }
    let(:policy_type) { :approval_policy }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:security_policy) }
  end

  describe 'validations' do
    describe 'content' do
      subject(:rule) { build(:approval_policy_rule, trait) }

      context 'when scan_finding' do
        let(:trait) { :scan_finding }

        it { is_expected.to be_valid }
      end

      context 'when license_finding' do
        let(:trait) { :license_finding }

        it { is_expected.to be_valid }
      end

      context 'when any_merge_request' do
        let(:trait) { :any_merge_request }

        it { is_expected.to be_valid }
      end
    end
  end
end
