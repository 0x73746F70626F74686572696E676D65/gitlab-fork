# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Index, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be(:zoekt_node) { create(:zoekt_node) }
  let_it_be(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: zoekt_node)
  end

  subject { zoekt_index }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_enabled_namespace).inverse_of(:indices) }
    it { is_expected.to belong_to(:node).inverse_of(:indices) }
    it { is_expected.to belong_to(:replica).inverse_of(:indices) }
    it { is_expected.to have_many(:zoekt_repositories).inverse_of(:zoekt_index) }
  end

  describe 'validations' do
    it 'validates that zoekt_enabled_namespace root_namespace_id matches namespace_id' do
      zoekt_index = described_class.new(zoekt_enabled_namespace: zoekt_enabled_namespace,
        node: zoekt_node, namespace_id: 0)
      expect(zoekt_index).to be_invalid
    end

    it 'validates presence of replica' do
      expect(zoekt_index).to be_valid
      zoekt_index.replica = nil
      expect(zoekt_index).not_to be_valid
    end
  end

  describe 'callbacks' do
    let_it_be(:namespace_2) { create(:group) }
    let_it_be(:another_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace_2) }

    describe '#create!' do
      it 'triggers indexing for the namespace' do
        expect(::Search::Zoekt::NamespaceIndexerWorker).to receive(:perform_async)
          .with(another_enabled_namespace.root_namespace_id, :index)

        another_replica = create(:zoekt_replica, zoekt_enabled_namespace: another_enabled_namespace)

        described_class.create!(zoekt_enabled_namespace: another_enabled_namespace, node: zoekt_node,
          namespace_id: another_enabled_namespace.root_namespace_id, replica: another_replica)
      end
    end

    describe '#destroy!' do
      it 'removes index for the namespace' do
        another_zoekt_index = create(:zoekt_index, zoekt_enabled_namespace: another_enabled_namespace,
          namespace_id: another_enabled_namespace.root_namespace_id)

        expect(::Search::Zoekt::NamespaceIndexerWorker).to receive(:perform_async)
          .with(another_enabled_namespace.root_namespace_id, :delete, another_zoekt_index.zoekt_node_id)

        another_zoekt_index.destroy!
      end

      it 'removes index when the enabled namespace record is destroyed' do
        another_zoekt_index = create(:zoekt_index, zoekt_enabled_namespace: another_enabled_namespace,
          namespace_id: another_enabled_namespace.root_namespace_id)

        expect(::Search::Zoekt::NamespaceIndexerWorker).to receive(:perform_async)
          .with(namespace_2.id, :delete, another_zoekt_index.zoekt_node_id)

        another_enabled_namespace.destroy!
      end
    end
  end

  describe 'scopes' do
    let_it_be(:namespace_2) { create(:group) }
    let_it_be_with_reload(:zoekt_enabled_namespace_2) { create(:zoekt_enabled_namespace, namespace: namespace_2) }
    let_it_be(:node_2) { create(:zoekt_node) }
    let_it_be(:zoekt_index_2) do
      create(:zoekt_index, node: node_2, zoekt_enabled_namespace: zoekt_enabled_namespace_2)
    end

    describe '#for_node' do
      subject { described_class.for_node(node_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }
    end

    describe '#for_root_namespace_id' do
      subject { described_class.for_root_namespace_id(namespace_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }

      context 'when there are orphaned indices' do
        before do
          zoekt_index_2.update!(zoekt_enabled_namespace: nil)
        end

        it { is_expected.to be_empty }
      end
    end

    describe '#for_root_namespace_id_with_search_enabled' do
      it 'correctly filters on the search field' do
        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to contain_exactly(zoekt_index_2)

        zoekt_enabled_namespace_2.update!(search: false)

        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to be_empty
      end
    end

    describe '#with_all_repositories_ready' do
      let_it_be(:idx) { create(:zoekt_index) } # It has some pending zoekt_repositories
      let_it_be(:idx2) { create(:zoekt_index) } # It has all ready zoekt_repositories
      let_it_be(:idx3) { create(:zoekt_index) } # It does not have zoekt_repositories
      let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx_project2) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx2_project2) { create(:project, namespace_id: idx2.namespace_id) }

      before do
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :pending)
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project2, state: :ready)
        idx2.zoekt_repositories.create!(zoekt_index: idx2, project: idx2_project2, state: :ready)
      end

      it 'returns all the indices whose all zoekt_repositories are ready' do
        expect(described_class.with_all_repositories_ready).to contain_exactly(idx2)
      end
    end

    describe '#searchable' do
      let_it_be(:zoekt_index_ready) do
        create(:zoekt_index, node: zoekt_node, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :ready)
      end

      it 'returns correct indices' do
        expect(described_class.searchable).to contain_exactly(zoekt_index_ready)
      end
    end

    describe '#preload_zoekt_enabled_namespace_and_namespace' do
      it 'preloads the project and avoids N+1 queries' do
        index = described_class.preload_zoekt_enabled_namespace_and_namespace.first
        recorder = ActiveRecord::QueryRecorder.new { index.zoekt_enabled_namespace.namespace }
        expect(recorder.count).to be_zero
      end
    end

    describe '#preload_node' do
      it 'preloads the node and avoids N+1 queries' do
        index = described_class.preload_node.first
        recorder = ActiveRecord::QueryRecorder.new { index.node }
        expect(recorder.count).to be_zero
      end
    end
  end
end
