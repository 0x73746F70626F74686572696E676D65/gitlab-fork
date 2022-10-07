# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Stage::ImportAttachmentsWorker do
  subject(:worker) { described_class.new }

  let(:project) { create(:project) }
  let!(:group) { create(:group, projects: [project]) }
  let(:feature_flag_state) { [group] }

  describe '#import' do
    let(:releases_importer) { instance_double('Gitlab::GithubImport::Importer::Attachments::ReleasesImporter') }
    let(:notes_importer) { instance_double('Gitlab::GithubImport::Importer::Attachments::NotesImporter') }
    let(:client) { instance_double('Gitlab::GithubImport::Client') }
    let(:releases_waiter) { Gitlab::JobWaiter.new(2, '123') }
    let(:notes_waiter) { Gitlab::JobWaiter.new(3, '234') }

    before do
      stub_feature_flags(github_importer_attachments_import: feature_flag_state)
    end

    it 'imports release attachments' do
      expect(Gitlab::GithubImport::Importer::Attachments::ReleasesImporter)
        .to receive(:new)
        .with(project, client)
        .and_return(releases_importer)
      expect(releases_importer).to receive(:execute).and_return(releases_waiter)

      expect(Gitlab::GithubImport::Importer::Attachments::NotesImporter)
        .to receive(:new)
        .with(project, client)
        .and_return(notes_importer)
      expect(notes_importer).to receive(:execute).and_return(notes_waiter)

      expect(Gitlab::GithubImport::AdvanceStageWorker)
        .to receive(:perform_async)
        .with(project.id, { '123' => 2, '234' => 3 }, :protected_branches)

      worker.import(client, project)
    end

    context 'when feature flag is disabled' do
      let(:feature_flag_state) { false }

      it 'skips release attachments import and calls next stage' do
        expect(Gitlab::GithubImport::Importer::Attachments::ReleasesImporter).not_to receive(:new)
        expect(Gitlab::GithubImport::Importer::Attachments::NotesImporter).not_to receive(:new)
        expect(Gitlab::GithubImport::AdvanceStageWorker)
          .to receive(:perform_async).with(project.id, {}, :protected_branches)

        worker.import(client, project)
      end
    end
  end
end
