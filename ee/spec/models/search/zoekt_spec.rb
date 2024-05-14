# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt, feature_category: :global_search do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be_with_reload(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group) }
  let_it_be_with_reload(:index) do
    create(:zoekt_index, :ready, zoekt_enabled_namespace: enabled_namespace, node: node)
  end

  let_it_be(:unassigned_group) { create(:group) }
  let_it_be_with_reload(:enabled_namespace_without_index) do
    create(:zoekt_enabled_namespace, namespace: unassigned_group)
  end

  describe '#fetch_node_id' do
    subject(:fetch_node_id) { described_class.fetch_node_id(container) }

    context 'when passed a project' do
      let(:container) { project }

      it { is_expected.to eq(node.id) }
    end

    context 'when passed a namespace' do
      let(:container) { group }

      it { is_expected.to eq(node.id) }
    end

    context 'when passed a subgroup' do
      let(:container) { subgroup }

      it { is_expected.to eq(node.id) }
    end

    context 'when passed a root namespace id' do
      let(:container) { group.id }

      it { is_expected.to eq(node.id) }
    end

    context 'when Zoekt::IndexedNamespace not found' do
      let(:container) { non_existing_record_id }

      it { is_expected.to be_nil }
    end

    context 'when passed an unsupported class' do
      let(:container) { instance_double(Issue) }

      it { expect { fetch_node_id }.to raise_error(ArgumentError) }
    end
  end

  describe '#search?' do
    subject(:search) { described_class.search?(container) }

    [true, false].each do |search|
      context "when search on the zoekt_enabled_namespace is set to #{search}" do
        before do
          enabled_namespace.update!(search: search)
        end

        context 'when passed a project' do
          let(:container) { project }

          it { is_expected.to eq(search) }
        end

        context 'when passed a namespace' do
          let(:container) { group }

          it { is_expected.to eq(search) }
        end

        context 'when passed a subgroup' do
          let(:container) { subgroup }

          it { is_expected.to eq(search) }
        end

        context 'when passed a root namespace id' do
          let(:container) { group.id }

          it { is_expected.to eq(search) }
        end
      end
    end

    context 'when no indices are ready' do
      let(:container) { project }

      before do
        index.update!(state: :initializing)
      end

      it { is_expected.to eq(false) }
    end

    context 'when Zoekt::EnabledNamespace not found' do
      let(:container) { build(:project) }

      it { is_expected.to eq(false) }
    end

    context 'when passed an unsupported class' do
      let(:container) { instance_double(Issue) }

      it { expect { search }.to raise_error(ArgumentError) }
    end
  end

  describe '#index?' do
    subject(:index) { described_class.index?(container) }

    context 'when passed a project' do
      let(:container) { project }

      it { is_expected.to eq(true) }
    end

    context 'when passed a namespace' do
      let(:container) { group }

      it { is_expected.to eq(true) }
    end

    context 'when passed a root namespace id' do
      let(:container) { group.id }

      it { is_expected.to eq(true) }
    end

    context 'when Zoekt::Index is not found' do
      let(:container) { build(:project) }

      it { is_expected.to eq(false) }
    end

    context 'when passed an unsupported class' do
      let(:container) { instance_double(Issue) }

      it { expect { index }.to raise_error(ArgumentError) }
    end

    context 'when group is unassigned' do
      let(:container) { unassigned_group }

      it { is_expected.to eq(false) }
    end
  end

  describe '#enabled_for_user?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:a_user) { create(:user) }

    subject(:enabled_for_user) { described_class.enabled_for_user?(user) }

    before do
      stub_feature_flags(search_code_with_zoekt: feature_flag)
      stub_licensed_features(zoekt_code_search: license_setting)

      allow(a_user).to receive(:enabled_zoekt?).and_return(user_setting)
    end

    where(:user, :feature_flag, :license_setting, :user_setting, :expected_result) do
      ref(:a_user) | true   | true  | true  | true
      ref(:a_user) | true   | true  | false | false
      ref(:a_user) | true   | false | true  | false
      ref(:a_user) | false  | true  | true  | false
      nil          | true   | true  | true  | true
    end

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#index_async' do
    subject(:index_async) { described_class.index_async(*args) }

    let(:args) { [project.id, { foo: :bar }] }

    it 'calls perform_async on the IndexerWorker and IndexingTaskWorker worker' do
      expect(Zoekt::IndexerWorker).to receive(:perform_async).with(*args)
      expect(described_class::IndexingTaskWorker).to receive(:perform_async).with(project.id, :index_repo)

      index_async
    end

    context 'when FF zoekt_legacy_indexer_worker is disabled' do
      before do
        stub_feature_flags(zoekt_legacy_indexer_worker: false)
      end

      it 'does not call perform_async on the worker' do
        expect(Zoekt::IndexerWorker).not_to receive(:perform_async)

        index_async
      end
    end

    context 'when FF zoekt_create_indexing_tasks is disabled' do
      before do
        stub_feature_flags(zoekt_create_indexing_tasks: false)
      end

      it 'does not call perform_async on the IndexingTaskWorker worker' do
        expect(described_class::IndexingTaskWorker).not_to receive(:perform_async)

        index_async
      end
    end
  end

  describe '#index_in' do
    subject(:index_in) { described_class.index_in(*args) }

    let(:args) { [1.minute, project.id, { foo: :bar }] }

    it 'calls perform_async on IndexingTaskWorker and perform_in on the IndexerWorker worker' do
      expect(described_class::IndexingTaskWorker).to receive(:perform_async)
        .with(project.id, :index_repo, { delay: 1.minute })
      expect(Zoekt::IndexerWorker).to receive(:perform_in).with(*args)
      index_in
    end

    context 'when FF zoekt_legacy_indexer_worker is disabled' do
      before do
        stub_feature_flags(zoekt_legacy_indexer_worker: false)
      end

      it 'does not call perform_in on the IndexerWorker worker' do
        expect(Zoekt::IndexerWorker).not_to receive(:perform_in)

        index_in
      end
    end

    context 'when FF zoekt_create_indexing_tasks is disabled' do
      before do
        stub_feature_flags(zoekt_create_indexing_tasks: false)
      end

      it 'does not call perform_async on the IndexingTaskWorker worker' do
        expect(described_class::IndexingTaskWorker).not_to receive(:perform_async)

        index_in
      end
    end
  end

  describe '#delete_async' do
    subject(:delete_async) { described_class.delete_async(*args, **keyword_args) }

    let(:args) { [project.id] }
    let(:keyword_args) { { root_namespace_id: project.root_ancestor.id, node_id: node.id } }
    let(:worker_args) { [project.root_ancestor.id, project.id, node.id] }

    it 'calls perform_async on the DeleteProjectWorker and IndexingTaskWorker worker' do
      expect(described_class::IndexingTaskWorker).to receive(:perform_async)
        .with(project.id, :delete_repo, { node_id: node.id, root_namespace_id: project.root_ancestor.id })
      expect(described_class::DeleteProjectWorker).to receive(:perform_async).with(*worker_args)

      delete_async
    end

    context 'when FF zoekt_legacy_indexer_worker is disabled' do
      before do
        stub_feature_flags(zoekt_legacy_indexer_worker: false)
      end

      it 'does not call perform_async on the DeleteProjectWorker worker' do
        expect(described_class::DeleteProjectWorker).not_to receive(:perform_async)

        delete_async
      end
    end

    context 'when FF zoekt_create_indexing_tasks is disabled' do
      before do
        stub_feature_flags(zoekt_create_indexing_tasks: false)
      end

      it 'does not call perform_async on the IndexingTaskWorker worker' do
        expect(described_class::IndexingTaskWorker).not_to receive(:perform_async)

        delete_async
      end
    end
  end

  describe '#delete_in' do
    subject(:delete_in) { described_class.delete_in(*args, **keyword_args) }

    let(:args) { [1.minute, project.id] }
    let(:keyword_args) { { root_namespace_id: project.root_ancestor.id, node_id: node.id } }
    let(:worker_args) { [1.minute, project.root_ancestor.id, project.id, node.id] }

    it 'calls perform_async on IndexingTaskWorker worker and perform_in on the DeleteProjectWorker worker' do
      options = { delay: 1.minute, node_id: node.id, root_namespace_id: project.root_ancestor.id }
      expect(described_class::IndexingTaskWorker).to receive(:perform_async).with(project.id, :delete_repo, options)
      expect(described_class::DeleteProjectWorker).to receive(:perform_in).with(*worker_args)

      delete_in
    end

    context 'when FF zoekt_legacy_indexer_worker is disabled' do
      before do
        stub_feature_flags(zoekt_legacy_indexer_worker: false)
      end

      it 'does not call perform_async on the DeleteProjectWorker worker' do
        expect(described_class::DeleteProjectWorker).not_to receive(:perform_in)

        delete_in
      end
    end

    context 'when FF zoekt_create_indexing_tasks is disabled' do
      before do
        stub_feature_flags(zoekt_create_indexing_tasks: false)
      end

      it 'does not call perform_async on the IndexingTaskWorker worker' do
        expect(described_class::IndexingTaskWorker).not_to receive(:perform_async)

        delete_in
      end
    end
  end
end
