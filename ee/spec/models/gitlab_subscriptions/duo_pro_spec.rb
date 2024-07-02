# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoPro, feature_category: :subscription_management do
  describe '.add_on_purchase_for_namespace' do
    let_it_be(:namespace) { create(:group) }

    subject { described_class.add_on_purchase_for_namespace(namespace) }

    context 'when there is an add_on_purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there is an add_on_purchase that is a trial' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there are no add_on_purchases' do
      it { is_expected.to be_nil }
    end
  end

  describe '.any_add_on_purchase_for_namespace_id' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.any_add_on_purchase_for_namespace_id(namespace.id) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be_nil }
    end
  end

  describe '.any_add_on_purchase_for_namespace' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.any_add_on_purchase_for_namespace(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when the add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :expired, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be_nil }
    end
  end

  describe '.no_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.no_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when the add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :expired, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be(true) }
    end
  end

  describe '.no_active_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.no_active_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an active add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :active, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is no active add-on purchase for the namespace' do
      context 'and there are no add-on purchases at all' do
        it { is_expected.to be(true) }
      end

      context 'and there is an expired add-on purchase' do
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :expired, namespace: namespace)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
