# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::IssuesSearch, feature_category: :global_search do
  let_it_be(:issue) { create(:issue) }
  let_it_be(:issue_epic_type) { create(:issue, :epic) }
  let_it_be(:work_item) { create(:work_item, :epic, :group_level) }
  let_it_be(:non_group_work_item) { create(:work_item) }

  before do
    issue_epic_type.project = nil # Need to set this to nil as :epic feature is not enforing it.
  end

  describe '#maintain_elasticsearch_update' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_call_original do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect((tracked_refs[0].is_a? WorkItem)).to be_true
      end
      non_group_work_item.maintain_elasticsearch_update
    end

    it 'does not calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
      issue_epic_type.maintain_elasticsearch_update
    end

    it 'does not calls track! for group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
      work_item.maintain_elasticsearch_update
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_call_original do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect((tracked_refs[0].is_a? Issue)).to be_true
      end

      issue.maintain_elasticsearch_update
    end
  end

  describe '#maintain_elasticsearch_destroy' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_call_original do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect((tracked_refs[0].is_a? WorkItem)).to be_true
      end
      non_group_work_item.maintain_elasticsearch_destroy
    end

    it 'does not calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
      issue_epic_type.maintain_elasticsearch_destroy
    end

    it 'does not calls track! for group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
      work_item.maintain_elasticsearch_destroy
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_call_original do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect((tracked_refs[0].is_a? Issue)).to be_true
      end

      issue.maintain_elasticsearch_destroy
    end
  end

  describe '#maintain_elasticsearch_create' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_call_original do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect((tracked_refs[0].is_a? WorkItem)).to be_true
      end
      non_group_work_item.maintain_elasticsearch_create
    end

    it 'does not calls track! for group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
      work_item.maintain_elasticsearch_create
    end

    it 'does not calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
      issue_epic_type.maintain_elasticsearch_create
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once.and_call_original do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect((tracked_refs[0].is_a? Issue)).to be_true
      end

      issue.maintain_elasticsearch_create
    end
  end
end
