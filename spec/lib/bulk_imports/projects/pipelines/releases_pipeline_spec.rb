# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Projects::Pipelines::ReleasesPipeline do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:bulk_import) { create(:bulk_import, user: user) }
  let_it_be(:entity) do
    create(
      :bulk_import_entity,
      :project_entity,
      project: project,
      bulk_import: bulk_import,
      source_full_path: 'source/full/path',
      destination_name: 'My Destination Project',
      destination_namespace: group.full_path
    )
  end

  let_it_be(:tracker) { create(:bulk_import_tracker, entity: entity) }
  let_it_be(:context) { BulkImports::Pipeline::Context.new(tracker) }

  let(:attributes) { {} }
  let(:release) do
    {
      'tag' => '1.1',
      'name' => 'release 1.1',
      'description' => 'Release notes',
      'created_at' => '2019-12-26T10:17:14.621Z',
      'updated_at' => '2019-12-26T10:17:14.621Z',
      'released_at' => '2019-12-26T10:17:14.615Z',
      'sha' => '901de3a8bd5573f4a049b1457d28bc1592ba6bf9'
    }.merge(attributes)
  end

  subject(:pipeline) { described_class.new(context) }

  describe '#run' do
    before do
      group.add_owner(user)
      with_index = [release, 0]

      allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
        allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: [with_index]))
      end

      pipeline.run
    end

    it 'imports release into destination project' do
      expect(project.releases.count).to eq(1)

      imported_release = project.releases.last

      aggregate_failures do
        expect(imported_release.tag).to eq(release['tag'])
        expect(imported_release.name).to eq(release['name'])
        expect(imported_release.description).to eq(release['description'])
        expect(imported_release.created_at.to_s).to eq('2019-12-26 10:17:14 UTC')
        expect(imported_release.updated_at.to_s).to eq('2019-12-26 10:17:14 UTC')
        expect(imported_release.released_at.to_s).to eq('2019-12-26 10:17:14 UTC')
        expect(imported_release.sha).to eq(release['sha'])
      end
    end

    context 'links' do
      let(:link) do
        {
          'url' => 'http://localhost/namespace6/project6/-/jobs/140463678/artifacts/download',
          'name' => 'release-1.1.dmg',
          'created_at' => '2019-12-26T10:17:14.621Z',
          'updated_at' => '2019-12-26T10:17:14.621Z'
        }
      end

      let(:attributes) {{ 'links' => [link] }}

      it 'restores release links' do
        release_link = project.releases.last.links.first

        aggregate_failures do
          expect(release_link.url).to eq(link['url'])
          expect(release_link.name).to eq(link['name'])
          expect(release_link.created_at.to_s).to eq('2019-12-26 10:17:14 UTC')
          expect(release_link.updated_at.to_s).to eq('2019-12-26 10:17:14 UTC')
        end
      end
    end

    context 'milestones' do
      let(:milestone) do
        {
          'iid' => 1,
          'state' => 'closed',
          'title' => 'test milestone',
          'description' => 'test milestone',
          'due_date' => '2016-06-14',
          'created_at' => '2016-06-14T15:02:04.415Z',
          'updated_at' => '2016-06-14T15:02:04.415Z'
        }
      end

      let(:attributes) {{ 'milestone_releases' => [{ 'milestone' => milestone }] }}

      it 'restores release milestone' do
        release_milestone = project.releases.last.milestone_releases.first.milestone

        aggregate_failures do
          expect(release_milestone.iid).to eq(milestone['iid'])
          expect(release_milestone.state).to eq(milestone['state'])
          expect(release_milestone.title).to eq(milestone['title'])
          expect(release_milestone.description).to eq(milestone['description'])
          expect(release_milestone.due_date.to_s).to eq('2016-06-14')
          expect(release_milestone.created_at.to_s).to eq('2016-06-14 15:02:04 UTC')
          expect(release_milestone.updated_at.to_s).to eq('2016-06-14 15:02:04 UTC')
        end
      end
    end
  end
end
