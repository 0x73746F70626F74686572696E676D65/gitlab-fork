# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoPro, feature_category: :subscription_management do
  describe '.eligible_namespace?' do
    context 'when namespace_id is blank' do
      it 'returns true for nil' do
        expect(described_class.eligible_namespace?(nil, [])).to be(true)
      end

      it 'returns true for empty string' do
        expect(described_class.eligible_namespace?('', [])).to be(true)
      end
    end

    context 'when namespace_id is present' do
      let_it_be(:namespace) { create(:group) }
      let(:eligible_namespaces) { Namespace.id_in(namespace.id) }

      it 'returns true for an eligible namespace' do
        expect(described_class.eligible_namespace?(namespace.id.to_s, eligible_namespaces)).to be(true)
      end

      it 'returns false for an in-eligible namespace' do
        expect(described_class.eligible_namespace?(non_existing_record_id.to_s, eligible_namespaces)).to be(false)
      end
    end
  end

  describe '.show_duo_pro_discover?' do
    subject { described_class.show_duo_pro_discover?(namespace, user) }

    let_it_be(:namespace) { create(:group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: namespace)
    end

    before do
      stub_saas_features(subscriptions_trials: true)
    end

    context 'when all conditions are met' do
      before_all do
        namespace.add_owner(user)
      end

      it { is_expected.to be_truthy }
    end

    context 'when namespace is not present' do
      let(:namespace) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when user is not present' do
      let(:user) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when licensed feature `subscriptions_trials` is not available' do
      before do
        stub_saas_features(subscriptions_trials: false)
      end

      it { is_expected.to be_falsey }
    end

    context 'when namespace does not have an active duo pro trial' do
      before do
        add_on_purchase.update!(expires_on: 1.day.ago)
      end

      it { is_expected.to be_falsey }
    end
  end
end
