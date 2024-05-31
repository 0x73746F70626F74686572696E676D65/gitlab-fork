# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::NamespaceInitialIndexingWorker, feature_category: :global_search do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  describe '#perform' do
    let_it_be(:namespace) { create(:group, :with_hierarchy, children: 1, depth: 3) }
    let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
    let_it_be(:zoekt_index) do
      create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, namespace_id: namespace.id)
    end

    let_it_be(:job_args) { [zoekt_index.id] }

    before do
      [namespace, namespace.children.first].each { |n| create(:project, namespace: n) }
    end

    subject(:perform_worker) { described_class.new.perform(*job_args) }

    context 'when license zoekt_code_search is not available' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it_behaves_like 'an idempotent worker' do
        it 'does not call the NamespaceInitialIndexingWorker on any child of the namespace' do
          expect(described_class).not_to receive(:perform_in)
          perform_worker
        end

        it 'does not call the Search::Zoekt.index_in and does not change the zoekt_index state to in_progress' do
          expect(Search::Zoekt).not_to receive(:index_in)
          expect { perform_worker }.not_to change { zoekt_index.reload.state }
        end
      end
    end

    context 'when namespace_id is also passed in the options' do
      context 'when invalid namespace_id is passed' do
        let(:job_args) { [zoekt_index.id, { namespace_id: non_existing_record_id }] }

        it_behaves_like 'an idempotent worker' do
          it 'does not call the NamespaceInitialIndexingWorker on any child of the namespace' do
            expect(described_class).not_to receive(:perform_in)
            perform_worker
          end

          it 'does not call the Search::Zoekt.index_in and does not change the zoekt_index state to in_progress' do
            expect(Search::Zoekt).not_to receive(:index_in)
            expect { perform_worker }.not_to change { zoekt_index.reload.state }
          end
        end
      end

      it_behaves_like 'an idempotent worker' do
        let(:passed_namespace) { namespace.children.first }
        let(:job_args) { [zoekt_index.id, { namespace_id: passed_namespace.id }] }

        it 'calls NamespaceInitialIndexingWorker on all the children of the passed namespace' do
          passed_namespace.children.each do |child|
            expect(described_class).to receive(:perform_in).with(be_between(0, described_class::DELAY_INTERVAL),
              zoekt_index.id, { namespace_id: child.id })
          end
          perform_worker
        end

        it 'calls the Search::Zoekt.index_in and changes the zoekt_index state to in_progress' do
          passed_namespace.projects.each do |project|
            expect(Search::Zoekt).to receive(:index_in)
            .with(be_between(0, described_class::DELAY_INTERVAL), project.id)
          end
          expect { perform_worker }.to change { zoekt_index.reload.state }.from('pending').to('in_progress')
        end
      end
    end

    it_behaves_like 'an idempotent worker' do
      it 'calls the NamespaceInitialIndexingWorker on all the children of the namespace' do
        namespace.children.each do |child|
          expect(described_class).to receive(:perform_in)
            .with(be_between(0, described_class::DELAY_INTERVAL), zoekt_index.id, { namespace_id: child.id })
        end
        perform_worker
      end

      it 'calls the Search::Zoekt.index_in and changes the zoekt_index state to in_progress' do
        namespace.projects.each do |project|
          expect(Search::Zoekt).to receive(:index_in)
          .with(be_between(0, described_class::DELAY_INTERVAL), project.id)
        end
        expect { perform_worker }.to change { zoekt_index.reload.state }.from('pending').to('in_progress')
      end
    end
  end
end
