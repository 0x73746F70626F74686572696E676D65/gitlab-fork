# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::EnabledNamespace, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }

  subject { create(:zoekt_enabled_namespace, namespace: namespace) }

  describe 'relations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:zoekt_enabled_namespace) }
    it { is_expected.to have_many(:indices) }
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

    describe '#search_enabled' do
      it 'returns namespaces that are enabled for search' do
        create(:zoekt_enabled_namespace, search: false)

        expect(described_class.search_enabled.count).to eq(1)
      end
    end

    describe '#for_root_namespace_id' do
      let_it_be(:another_zoekt_enabled_namespace) { create(:zoekt_enabled_namespace) }

      it 'returns records for the specified namespace' do
        expect(described_class.for_root_namespace_id(namespace.id).count).to eq(1)
      end
    end

    describe '#recent' do
      it 'returns ordered by id desc' do
        zoekt_enabled_namespace_2 = create(:zoekt_enabled_namespace)

        expect(described_class.recent).to match([zoekt_enabled_namespace_2, zoekt_enabled_namespace])
      end
    end

    describe '#with_limit' do
      it 'returns only the amount of records requested' do
        create(:zoekt_enabled_namespace)

        expect(described_class.with_limit(1).count).to eq(1)
      end
    end
  end
end
