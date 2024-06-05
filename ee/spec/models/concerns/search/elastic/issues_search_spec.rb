# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::IssuesSearch, :elastic_helpers, feature_category: :global_search do
  let_it_be(:issue) { create(:issue) }
  let_it_be(:issue_epic_type) { create(:issue, :epic) }
  let_it_be(:work_item) { create(:work_item, :epic, :group_level) }
  let_it_be(:non_group_work_item) { create(:work_item) }

  before do
    issue_epic_type.project = nil # Need to set this to nil as :epic feature is not enforing it.
  end

  describe '#maintain_elasticsearch_update' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(::Gitlab::Elastic::DocumentReference)
        expect(tracked_refs[0].db_id).to eq(non_group_work_item.id.to_s)
        expect(tracked_refs[0].klass).to eq(Issue)
      end

      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(WorkItem)
      end

      non_group_work_item.maintain_elasticsearch_update
    end

    it 'calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(0)
      end

      issue_epic_type.maintain_elasticsearch_update
    end

    it 'calls track! for group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(0)
      end
      work_item.maintain_elasticsearch_update
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(Issue)
        expect(tracked_refs[0].id).to eq(issue.id)
      end
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(Issue)
      end

      issue.maintain_elasticsearch_update
    end
  end

  describe '#maintain_elasticsearch_destroy' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(::Gitlab::Elastic::DocumentReference)
        expect(tracked_refs[0].db_id).to eq(non_group_work_item.id.to_s)
        expect(tracked_refs[0].klass).to eq(Issue)
      end

      non_group_work_item.maintain_elasticsearch_destroy
    end

    it 'calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(0)
      end

      issue_epic_type.maintain_elasticsearch_destroy
    end

    it 'calls track! for group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(0)
      end
      work_item.maintain_elasticsearch_destroy
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(Issue)
        expect(tracked_refs[0].id).to eq(issue.id)
      end

      issue.maintain_elasticsearch_destroy
    end
  end

  describe '#maintain_elasticsearch_create' do
    it 'calls track! for non group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(::Gitlab::Elastic::DocumentReference)
        expect(tracked_refs[0].db_id).to eq(non_group_work_item.id.to_s)
        expect(tracked_refs[0].klass).to eq(Issue)
      end

      non_group_work_item.maintain_elasticsearch_create
    end

    it 'calls track! for group level WorkItem' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(0)
      end
      work_item.maintain_elasticsearch_create
    end

    it 'calls track! for group level Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(0)
      end
      issue_epic_type.maintain_elasticsearch_create
    end

    it 'calls track! with Issue' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
        expect(tracked_refs.count).to eq(1)
        expect(tracked_refs[0]).to be_a_kind_of(Issue)
        expect(tracked_refs[0].id).to eq(issue.id)
      end

      issue.maintain_elasticsearch_create
    end
  end
end
