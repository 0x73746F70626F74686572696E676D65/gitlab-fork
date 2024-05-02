# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Projects::Pipelines::IssuesPipeline, feature_category: :importers do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:bulk_import) { create(:bulk_import, user: user) }
  let_it_be(:filepath) { 'spec/fixtures/bulk_imports/gz/issues.ndjson.gz' }
  let_it_be(:entity) do
    create(
      :bulk_import_entity,
      :project_entity,
      project: project,
      bulk_import: bulk_import,
      source_full_path: 'source/full/path',
      destination_slug: 'My-Destination-Project',
      destination_namespace: group.full_path
    )
  end

  let_it_be(:tracker) { create(:bulk_import_tracker, entity: entity) }
  let_it_be(:context) { BulkImports::Pipeline::Context.new(tracker) }

  let(:issue) do
    {
      'title' => 'Imported Issue',
      'description' => 'Description',
      'state' => 'opened',
      'updated_at' => '2016-06-14T15:02:47.967Z',
      'author_id' => 22,
      'epic_issue' => {
        'id' => 78,
        'relative_position' => 1073740323,
        'epic' => {
          'title' => 'An epic',
          'state_id' => 'opened',
          'author_id' => 22
        }
      }
    }
  end

  subject(:pipeline) { described_class.new(context) }

  describe '#run', :clean_gitlab_redis_shared_state do
    before do
      stub_licensed_features(epics: true)

      group.add_owner(user)
      issue_with_index = [issue, 0]

      allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
        allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: [issue_with_index]))
      end

      allow(pipeline).to receive(:set_source_objects_counter)
    end

    context 'with pre-existing epic' do
      it 'associates existing epic with imported issue' do
        epic = create(:epic, title: 'An epic', group: group)

        expect { pipeline.run }.not_to change { Epic.count }

        expect(group.epics.count).to eq(1)
        expect(project.issues.first.epic).to eq(epic)
        expect(project.issues.first.epic_issue.relative_position).not_to be_nil

        group.epics.each do |epic|
          expect(epic.work_item).not_to be_nil

          diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
          expect(diff.attributes).to be_empty
        end
      end
    end

    context 'without pre-existing epic' do
      it 'creates a new epic for imported issue' do
        group.epics.delete_all

        expect { pipeline.run }.to change { Epic.count }.from(0).to(1)
        expect(group.epics.count).to eq(1)

        expect(project.issues.first.epic).not_to be_nil
        expect(project.issues.first.epic_issue.relative_position).not_to be_nil

        group.epics.each do |epic|
          expect(epic.work_item).not_to be_nil

          diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
          expect(diff.attributes).to be_empty
        end
      end
    end
  end
end
