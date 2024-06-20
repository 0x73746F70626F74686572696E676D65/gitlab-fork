# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::EpicsSearch, :elastic, feature_category: :global_search do
  let_it_be(:epic) { create(:epic) }

  describe '#maintain_elasticsearch_create' do
    it 'calls track! for epic' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(2)
        expect(tracked_refs[0].class).to eq(Epic)
        expect(tracked_refs[0].id).to eq(epic.id)
        expect(tracked_refs[1]).to be_a_kind_of(Search::Elastic::References::WorkItem)
        expect(tracked_refs[1].identifier).to eq(epic.issue_id)
      end

      epic.maintain_elasticsearch_create
    end
  end

  describe '#maintain_elasticsearch_destory' do
    it 'calls track! for epic' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(2)
        expect(tracked_refs[0].class).to eq(Epic)
        expect(tracked_refs[0].id).to eq(epic.id)
        expect(tracked_refs[1]).to be_a_kind_of(Search::Elastic::References::WorkItem)
        expect(tracked_refs[1].identifier).to eq(epic.issue_id)
      end

      epic.maintain_elasticsearch_destroy
    end
  end

  describe '#maintain_elasticsearch_update' do
    it 'calls track! for epic' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(2)
        expect(tracked_refs[0].class).to eq(Epic)
        expect(tracked_refs[0].id).to eq(epic.id)
        expect(tracked_refs[1]).to be_a_kind_of(Search::Elastic::References::WorkItem)
        expect(tracked_refs[1].identifier).to eq(epic.issue_id)
      end

      epic.maintain_elasticsearch_update
    end

    context 'when we have associations to update' do
      before do
        allow(Epic).to receive(:elastic_index_dependants).and_return([{ association_name: :issues,
                                                                        on_change: 'title' }])
      end

      it 'calls track! for epic and updates the associations' do
        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
          expect(tracked_refs.count).to eq(2)
          expect(tracked_refs[0].class).to eq(Epic)
          expect(tracked_refs[0].id).to eq(epic.id)
          expect(tracked_refs[1]).to be_a_kind_of(Search::Elastic::References::WorkItem)
          expect(tracked_refs[1].identifier).to eq(epic.issue_id)
        end

        expect(::ElasticAssociationIndexerWorker).to receive(:perform_async).with('Epic', epic.id, ['issues']).once
        epic.maintain_elasticsearch_update
      end
    end
  end
end
