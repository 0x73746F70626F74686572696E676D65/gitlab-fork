# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::IssuesSearch, :elastic_helpers, feature_category: :global_search do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:issue_epic_type) { create(:issue, :epic) }
  let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level) }
  let_it_be(:non_group_work_item) { create(:work_item) }
  let(:helper) { Gitlab::Elastic::Helper.default }

  before do
    issue_epic_type.project = nil # Need to set this to nil as :epic feature is not enforing it.
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
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

    it 'calls track! for synced_epic' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[work_item.synced_epic])
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

    describe 'tracking embeddings' do
      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
        allow(helper).to receive(:vectors_supported?).and_return(true)
        allow(Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
      end

      context 'for issue' do
        subject(:record) { issue }

        it 'tracks the embedding' do
          expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!).with(record)

          record.maintain_elasticsearch_update
        end

        context 'when the project is not public' do
          before do
            allow(project).to receive(:public?).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when a title or description is not updated' do
          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update(updated_attributes: ['id'])
          end
        end

        context 'when ai_global_switch feature flag is disabled' do
          before do
            stub_feature_flags(ai_global_switch: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when ai_vertex_embeddings feature is not available' do
          before do
            allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when elaticsearch_issue_upsert feature flag is disabled' do
          before do
            stub_feature_flags(elaticsearch_issue_upsert: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when elasticsearch_issue_embedding feature flag is disabled' do
          before do
            stub_feature_flags(elasticsearch_issue_embedding: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end

        context 'when vectors are not supported' do
          before do
            allow(helper).to receive(:vectors_supported?).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_update
          end
        end
      end

      it 'does not track the embedding for group level issue' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        issue_epic_type.maintain_elasticsearch_update
      end

      it 'does not track the embedding for project level work item' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        non_group_work_item.maintain_elasticsearch_update
      end

      it 'does not track the embedding for group level work item' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        work_item.maintain_elasticsearch_update
      end
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

    it 'calls track! for synced_epic' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[work_item.synced_epic])
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

    it 'calls track! for synced_epic' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(*[work_item.synced_epic])
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

    describe 'tracking embeddings' do
      before do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(true)
        allow(helper).to receive(:vectors_supported?).and_return(true)
        allow(Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
      end

      context 'for issue' do
        subject(:record) { issue }

        it 'tracks the embedding' do
          expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).to receive(:track_embedding!).with(record)

          record.maintain_elasticsearch_create
        end

        context 'when the project is not public' do
          before do
            allow(project).to receive(:public?).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when ai_global_switch feature flag is disabled' do
          before do
            stub_feature_flags(ai_global_switch: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when ai_vertex_embeddings feature is not available' do
          before do
            allow(Gitlab::Saas).to receive(:feature_available?).with(:ai_vertex_embeddings).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when elaticsearch_issue_upsert feature flag is disabled' do
          before do
            stub_feature_flags(elaticsearch_issue_upsert: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when elasticsearch_issue_embedding feature flag is disabled' do
          before do
            stub_feature_flags(elasticsearch_issue_embedding: false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end

        context 'when vectors are not supported' do
          before do
            allow(helper).to receive(:vectors_supported?).and_return(false)
          end

          it 'does not track the embedding' do
            expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

            record.maintain_elasticsearch_create
          end
        end
      end

      it 'does not track the embedding for group level issue' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        issue_epic_type.maintain_elasticsearch_create
      end

      it 'does not track the embedding for project level work item' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        non_group_work_item.maintain_elasticsearch_create
      end

      it 'does not track the embedding for group level work item' do
        expect(::Search::Elastic::ProcessEmbeddingBookkeepingService).not_to receive(:track_embedding!)

        work_item.maintain_elasticsearch_create
      end
    end
  end
end
