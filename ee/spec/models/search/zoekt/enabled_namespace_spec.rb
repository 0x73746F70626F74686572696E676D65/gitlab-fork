# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::EnabledNamespace, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }

  subject { create(:zoekt_enabled_namespace, namespace: namespace) }

  describe 'relations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:zoekt_enabled_namespace) }
    it { is_expected.to have_many(:indices) }
    it { is_expected.to have_many(:replicas) }
    it { is_expected.to have_many(:nodes).through(:indices) }
  end

  describe 'validations' do
    it 'only allows root namespaces to be indexed' do
      subgroup = create(:group, parent: namespace)

      expect(described_class.new(namespace: subgroup)).to be_invalid
    end
  end

  describe 'scopes' do
    let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }

    describe '.for_root_namespace_id' do
      let_it_be(:another_zoekt_enabled_namespace) { create(:zoekt_enabled_namespace) }

      it 'returns records for the specified namespace' do
        expect(described_class.for_root_namespace_id(namespace.id).count).to eq(1)
      end
    end

    describe '.preload_storage_statistics' do
      it 'returns Search::Zoekt::EnabledNamespace with missing zoekt index' do
        result = described_class.preload_storage_statistics.first
        expect(result.association(:namespace)).to be_loaded
        expect(result.namespace.association(:root_storage_statistics)).to be_loaded
        result = described_class.first
        expect(result.association(:namespace)).not_to be_loaded
        expect(result.namespace.association(:root_storage_statistics)).not_to be_loaded
      end
    end

    describe '.recent' do
      it 'returns ordered by id desc' do
        zoekt_enabled_namespace_2 = create(:zoekt_enabled_namespace)

        expect(described_class.recent).to match([zoekt_enabled_namespace_2, zoekt_enabled_namespace])
      end
    end

    describe '.search_enabled' do
      it 'returns namespaces that are enabled for search' do
        create(:zoekt_enabled_namespace, search: false)

        expect(described_class.search_enabled.count).to eq(1)
      end
    end

    describe '.with_limit' do
      it 'returns only the amount of records requested' do
        create(:zoekt_enabled_namespace)

        expect(described_class.with_limit(1).count).to eq(1)
      end
    end

    describe '.with_missing_indices' do
      let_it_be(:zoekt_enabled_namespace2) { create(:zoekt_enabled_namespace) }

      before do
        create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace2)
      end

      it 'returns Search::Zoekt::EnabledNamespace with missing zoekt index' do
        expect(described_class.with_missing_indices).to contain_exactly(zoekt_enabled_namespace)
      end
    end

    describe '.destroy_namespaces_with_expired_subscriptions!', :saas do
      subject(:destroy_namespaces) { described_class.destroy_namespaces_with_expired_subscriptions! }

      let_it_be(:expired_date) { Date.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD }
      let_it_be(:expired_subscription) { create(:gitlab_subscription, :ultimate, end_date: expired_date - 1.day) }
      let_it_be(:grace_period_subscription) { create(:gitlab_subscription, :ultimate, end_date: expired_date + 1.day) }
      let_it_be(:ultimate_subscription) { create(:gitlab_subscription, :ultimate) }

      let_it_be(:zoekt_enabled_namespace_ultimate_expired) do
        create(:zoekt_enabled_namespace, namespace: expired_subscription.namespace)
      end

      let_it_be(:zoekt_enabled_namespace_ultimate_grace_period) do
        create(:zoekt_enabled_namespace, namespace: grace_period_subscription.namespace)
      end

      let_it_be(:zoekt_enabled_namespace_ultimate) do
        create(:zoekt_enabled_namespace, namespace: ultimate_subscription.namespace)
      end

      it 'destroys expired subscriptions' do
        expect { destroy_namespaces }.to change { ::Search::Zoekt::EnabledNamespace.count }.by(-2)

        expect(described_class.all).to contain_exactly(
          zoekt_enabled_namespace_ultimate_grace_period,
          zoekt_enabled_namespace_ultimate
        )
      end
    end
  end
end
