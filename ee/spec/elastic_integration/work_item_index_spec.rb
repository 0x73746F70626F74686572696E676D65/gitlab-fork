# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'WorkItem Index', :elastic, :sidekiq_inline, feature_category: :global_search do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be_with_refind(:work_item) { create(:work_item, project: project) }
  let(:helper) { Gitlab::Elastic::Helper.default }
  let(:client) { helper.client }

  shared_examples 'work_items get tracked in Elasticsearch' do
    it 'use_elasticsearch? is true' do
      expect(work_item).to be_use_elasticsearch
    end

    context 'when a work_item is created' do
      it 'tracks the work_item' do
        work_item_ref = build(:work_item, project: project)
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(tracked_refs_count)

          if tracked_refs_count == 1
            expect(tracked_refs[0]).to be_a_kind_of(Gitlab::Elastic::DocumentReference)
            expect(tracked_refs[0].klass).to eq(Issue)
            expect(tracked_refs[0].db_id).to eq(work_item_ref.id.to_s)
          else
            expect(tracked_refs[0]).to be_a_kind_of(WorkItem)
            expect(tracked_refs[1]).to be_a_kind_of(Gitlab::Elastic::DocumentReference)
            expect(tracked_refs[1].klass).to eq(Issue)
            expect(tracked_refs[1].db_id).to eq(work_item_ref.id.to_s)
          end
        end

        work_item_ref.save!
      end
    end

    context 'when a work_item is updated' do
      it 'tracks the work_item' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(tracked_refs_count)

          if tracked_refs_count == 1
            expect(tracked_refs[0]).to be_a_kind_of(Gitlab::Elastic::DocumentReference)
            expect(tracked_refs[0].klass).to eq(Issue)
            expect(tracked_refs[0].db_id).to eq(work_item.id.to_s)
          else
            expect(tracked_refs[0]).to be_a_kind_of(WorkItem)
            expect(tracked_refs[1]).to be_a_kind_of(Gitlab::Elastic::DocumentReference)
            expect(tracked_refs[1].klass).to eq(Issue)
            expect(tracked_refs[1].db_id).to eq(work_item.id.to_s)
          end
        end

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(1)
          expect(tracked_refs[0]).to be_a_kind_of(WorkItem)
        end
        work_item.update!(title: 'A new title')
      end
    end

    context 'when a work_item is deleted' do
      it 'tracks the work_item' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(tracked_refs_count)

          if tracked_refs_count == 1
            expect(tracked_refs[0]).to be_a_kind_of(Gitlab::Elastic::DocumentReference)
            expect(tracked_refs[0].klass).to eq(Issue)
            expect(tracked_refs[0].db_id).to eq(work_item.id.to_s)
          else
            expect(tracked_refs[0]).to be_a_kind_of(WorkItem)
            expect(tracked_refs[1]).to be_a_kind_of(Gitlab::Elastic::DocumentReference)
            expect(tracked_refs[1].klass).to eq(Issue)
            expect(tracked_refs[1].db_id).to eq(work_item.id.to_s)
          end
        end

        work_item.destroy!
      end

      it 'deletes the work_item from elasticsearch' do
        allow(::Elastic::ProcessBookkeepingService).to receive(:track!).and_call_original

        work_item = create(:work_item, project: project)
        ensure_elasticsearch_index!
        expect(work_items_in_index).to eq([work_item.id])

        work_item.destroy!

        ensure_elasticsearch_index!
        expect(work_items_in_index).to be_empty
      end
    end
  end

  shared_examples 'work_items do not get tracked in Elasticsearch' do
    it 'use_elasticsearch? is false' do
      expect(work_item).not_to be_use_elasticsearch
    end

    context 'when a work_item is created' do
      it 'does not track the work_item' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(work_item)
        work_item.save!
      end
    end

    context 'when a work_item is updated' do
      it 'does not track the work_item' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(work_item)
        work_item.update!(title: 'A new title')
      end
    end

    context 'when a work_item is deleted' do
      it 'does not track the work_item' do
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(work_item)
        work_item.destroy!
      end
    end
  end

  context 'when feature flag is turned off work_items indexed in issues index' do
    let(:index_name) { Issue.__elasticsearch__.index_name }
    let(:tracked_refs_count) { 1 }

    before do
      stub_feature_flags(elastic_index_work_items: false)
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it_behaves_like 'work_items get tracked in Elasticsearch'

    context 'when indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it_behaves_like 'work_items do not get tracked in Elasticsearch'
    end
  end

  context 'when feature flag is turned on and migration is complete' do
    let(:index_name) { ::Search::Elastic::References::WorkItem.index }
    let(:tracked_refs_count) { 2 }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it_behaves_like 'work_items get tracked in Elasticsearch'

    context 'when indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it_behaves_like 'work_items do not get tracked in Elasticsearch'
    end
  end

  def work_items_in_index
    client.search(index: index_name).dig('hits', 'hits').map { |hit| hit['_source']['id'] }
  end
end
