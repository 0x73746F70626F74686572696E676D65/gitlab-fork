# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::WikiSyncService, :geo do
  include ::EE::GeoHelpers
  include ExclusiveLeaseHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }
  let_it_be(:project) { create(:project_empty_repo, :wiki_repo) }

  let(:repository) { project.wiki.repository }
  let(:temp_repo) { subject.send(:temp_repo) }
  let(:lease_key) { "geo_sync_service:wiki:#{project.id}" }
  let(:lease_uuid) { 'uuid' }
  let(:url_to_repo) { "#{primary.url}#{project.full_path}.wiki.git" }

  subject { described_class.new(project) }

  before do
    stub_current_geo_node(secondary)
  end

  it_behaves_like 'geo base sync execution'
  it_behaves_like 'geo base sync fetch'
  it_behaves_like 'reschedules sync due to race condition instead of waiting for backfill'

  describe '#execute', :aggregate_failures do
    before do
      stub_exclusive_lease(lease_key, lease_uuid)

      allow(repository).to receive(:fetch_as_mirror).and_return(true)
      allow(repository).to receive(:clone_as_mirror).and_return(true)

      # Simulates a successful clone, by making sure a repository is created
      allow(temp_repo).to receive(:clone_as_mirror) do
        temp_repo.create_repository
      end
    end

    include_context 'lease handling'

    context 'with existing repository' do
      it 'fetches wiki repository with JWT credentials' do
        expect(repository).to receive(:fetch_as_mirror)
                                .with(url_to_repo, forced: true, http_authorization_header: anything)
                                .once

        subject.execute
      end

      it 'voids the failure message when it succeeds after an error' do
        allow(repository).to receive(:update_root_ref)

        project_repository_registry = create(:geo_project_registry, project: project, last_wiki_sync_failure: 'error')
        wiki_repository_registry = create(:geo_project_wiki_repository_registry, project: project, last_sync_failure: 'error')

        subject.execute

        expect(project_repository_registry.reload.last_wiki_sync_failure).to be_nil
        expect(wiki_repository_registry.reload.last_sync_failure).to be_nil
      end

      it 'rescues exception when Gitlab::Shell::Error is raised' do
        allow(repository).to receive(:fetch_as_mirror)
                               .with(url_to_repo, forced: true, http_authorization_header: anything)
                               .and_raise(Gitlab::Shell::Error)

        expect { subject.execute }.not_to raise_error
      end

      it 'rescues exception when Gitlab::Git::Repository::NoRepository is raised' do
        allow(repository).to receive(:fetch_as_mirror)
                               .with(url_to_repo, forced: true, http_authorization_header: anything)
                               .and_raise(Gitlab::Git::Repository::NoRepository)

        expect { subject.execute }.not_to raise_error
      end

      it 'increases retry count when Gitlab::Git::Repository::NoRepository is raised' do
        allow(repository).to receive(:fetch_as_mirror)
                               .with(url_to_repo, forced: true, http_authorization_header: anything)
                               .and_raise(Gitlab::Git::Repository::NoRepository)

        subject.execute

        expect(Geo::ProjectRegistry.last)
          .to have_attributes(resync_wiki: true, wiki_retry_count: 1)

        expect(Geo::ProjectWikiRepositoryRegistry.last)
          .to have_attributes(state: Geo::ProjectWikiRepositoryRegistry.state_value(:failed), retry_count: 1)
      end

      it 'marks sync as successful if no repository found' do
        project_repository_registry = create(:geo_project_registry, project: project)
        wiki_repository_registry = create(:geo_project_wiki_repository_registry, project: project)

        allow(repository).to receive(:fetch_as_mirror)
                               .with(url_to_repo, forced: true, http_authorization_header: anything)
                               .and_raise(Gitlab::Shell::Error.new(Gitlab::GitAccessWiki::ERROR_MESSAGES[:no_repo]))

        subject.execute

        expect(project_repository_registry.reload).to have_attributes(
          resync_wiki: false,
          last_wiki_successful_sync_at: be_present,
          wiki_missing_on_primary: true
        )

        expect(wiki_repository_registry.reload).to have_attributes(
          state: Geo::ProjectWikiRepositoryRegistry.state_value(:synced),
          last_synced_at: be_present,
          missing_on_primary: true
        )
      end

      it 'marks resync as true after a failure' do
        described_class.new(project).execute

        allow(repository).to receive(:fetch_as_mirror)
                               .with(url_to_repo, forced: true, http_authorization_header: anything)
                               .and_raise(Gitlab::Git::Repository::NoRepository)

        subject.execute

        expect(Geo::ProjectRegistry.last.resync_wiki).to be true
        expect(Geo::ProjectWikiRepositoryRegistry.last.state).to eq(Geo::ProjectWikiRepositoryRegistry.state_value(:failed))
      end
    end

    context 'wiki repository presumably exists on primary' do
      it 'increases retry count if no wiki repository found' do
        create(:repository_state, :wiki_verified, project: project)
        create(:geo_project_wiki_repository_state, :checksummed, project: project)
        project_repository_registry = create(:geo_project_registry, project: project)
        wiki_repository_registry = create(:geo_project_wiki_repository_registry, project: project)

        allow(repository).to receive(:fetch_as_mirror)
          .with(url_to_repo, forced: true, http_authorization_header: anything)
          .and_raise(Gitlab::Shell::Error.new(Gitlab::GitAccessWiki::ERROR_MESSAGES[:no_repo]))

        subject.execute

        expect(project_repository_registry.reload).to have_attributes(
          resync_wiki: true,
          wiki_retry_count: 1
        )

        expect(wiki_repository_registry.reload).to have_attributes(
          state: Geo::ProjectWikiRepositoryRegistry.state_value(:failed),
          retry_count: 1
        )
      end
    end

    it 'marks primary_wiki_checksummed as true when wiki has been verified on primary' do
      allow(repository).to receive(:update_root_ref)

      create(:repository_state, :wiki_verified, project: project)
      create(:geo_project_wiki_repository_state, :checksummed, project: project)
      project_repository_registry = create(:geo_project_registry, project: project, primary_wiki_checksummed: false)

      expect { subject.execute }
        .to change { project_repository_registry.reload.primary_wiki_checksummed }
        .from(false)
        .to(true)
    end

    it 'marks primary_wiki_checksummed as false when wiki has not been verified on primary' do
      allow(repository).to receive(:update_root_ref)

      create(:repository_state, :wiki_failed, project: project)
      create(:geo_project_wiki_repository_state, :checksum_failure, project: project)
      project_repository_registry = create(:geo_project_registry, project: project, primary_wiki_checksummed: true)

      expect { subject.execute }
        .to change { project_repository_registry.reload.primary_wiki_checksummed }
        .from(true)
        .to(false)
    end

    context 'tracking database' do
      context 'temporary repositories' do
        include_examples 'cleans temporary repositories'
      end

      it 'creates a new registry if does not exists' do
        expect { subject.execute }
          .to change(Geo::ProjectRegistry, :count).by(1)
          .and change(Geo::ProjectWikiRepositoryRegistry, :count).by(1)
      end

      it 'does not create a new registry if one exists' do
        create(:geo_project_registry, project: project)
        create(:geo_project_wiki_repository_registry, project: project)

        expect { subject.execute }
          .to change(Geo::ProjectRegistry, :count).by(0)
          .and change(Geo::ProjectWikiRepositoryRegistry, :count).by(0)
      end

      context 'when repository sync succeed' do
        let(:project_repository_registry) { Geo::ProjectRegistry.find_by(project_id: project.id) }
        let(:wiki_repository_registry) { Geo::ProjectWikiRepositoryRegistry.find_by(project_id: project.id) }

        it 'sets last_wiki_synced_at' do
          subject.execute

          expect(project_repository_registry.last_wiki_synced_at).to be_present
          expect(wiki_repository_registry.last_synced_at).to be_present
        end

        it 'sets last_wiki_successful_sync_at' do
          allow(repository).to receive(:update_root_ref)

          subject.execute

          expect(project_repository_registry.last_wiki_successful_sync_at).to be_present
          expect(wiki_repository_registry.last_synced_at).to be_present
        end

        it 'resets the wiki_verification_checksum_sha' do
          subject.execute

          expect(project_repository_registry.wiki_verification_checksum_sha).to be_nil
          expect(wiki_repository_registry.verification_checksum).to be_nil
        end

        it 'resets the last_wiki_verification_failure' do
          subject.execute

          expect(project_repository_registry.last_wiki_verification_failure).to be_nil
          expect(wiki_repository_registry.verification_failure).to be_nil
        end

        it 'resets the wiki_checksum_mismatch' do
          subject.execute

          expect(project_repository_registry.wiki_checksum_mismatch).to eq false
          expect(wiki_repository_registry.verification_checksum_mismatched).to be_nil
        end

        it 'logs success with timings' do
          allow(repository).to receive(:update_root_ref)
          allow(Gitlab::Geo::Logger).to receive(:info).and_call_original

          expect(Gitlab::Geo::Logger).to receive(:info).with(hash_including(:message, :download_time_s)).and_call_original

          subject.execute
        end
      end

      context 'when wiki sync fail' do
        before do
          allow(repository).to receive(:fetch_as_mirror)
            .with(url_to_repo, forced: true, http_authorization_header: anything)
            .and_raise(Gitlab::Shell::Error.new('shell error'))
        end

        it 'sets correct values for registry record' do
          subject.execute

          project_repository_registry = Geo::ProjectRegistry.find_by(project_id: project.id)
          wiki_repository_registry = Geo::ProjectWikiRepositoryRegistry.find_by(project_id: project.id)

          expect(project_repository_registry)
            .to have_attributes(
              last_wiki_synced_at: be_present,
              last_wiki_successful_sync_at: nil,
              last_wiki_sync_failure: 'Error syncing wiki repository: shell error'
            )

          expect(wiki_repository_registry)
            .to have_attributes(
              last_synced_at: be_present,
              state: Geo::ProjectWikiRepositoryRegistry.state_value(:failed),
              last_sync_failure: 'Error syncing wiki repository: shell error'
            )
        end
      end

      context 'no Wiki repository' do
        let(:project) { create(:project, :repository) }

        it 'does not raise an error' do
          create(:geo_project_registry, project: project, force_to_redownload_wiki: true)
          create(:geo_project_wiki_repository_registry, project: project, force_to_redownload: true)

          allow(repository).to receive(:update_root_ref)
          expect(repository).to receive(:expire_exists_cache).exactly(3).times.and_call_original
          expect(subject).not_to receive(:fail_registry_sync!)

          subject.execute
        end
      end
    end

    it_behaves_like 'sync retries use the snapshot RPC' do
      let(:retry_count) { Geo::WikiSyncService::RETRIES_BEFORE_REDOWNLOAD }

      def registry_with_retry_count(retries)
        create(:geo_project_wiki_repository_registry, project: project, retry_count: retries)
      end
    end
  end

  context 'when the repository is redownloaded' do
    context 'with geo_use_clone_on_first_sync flag disabled' do
      before do
        stub_feature_flags(geo_use_clone_on_first_sync: false)
        allow(subject).to receive(:should_be_redownloaded?).and_return(true)
      end

      it 'creates a new repository and fetches with JWT credentials' do
        expect(temp_repo).to receive(:create_repository)
        expect(temp_repo).to receive(:fetch_as_mirror)
                               .with(url_to_repo, forced: true, http_authorization_header: anything)
                               .once
        expect(subject).to receive(:set_temp_repository_as_main)

        subject.execute
      end

      it 'cleans temporary repo after redownload' do
        expect(subject).to receive(:fetch_geo_mirror).with(target_repository: temp_repo)
        expect(subject).to receive(:clean_up_temporary_repository).twice.and_call_original

        subject.execute
      end
    end

    context 'with geo_use_clone_on_first_sync flag enabled' do
      before do
        stub_feature_flags(geo_use_clone_on_first_sync: true)
        allow(subject).to receive(:should_be_redownloaded?).and_return(true)
      end

      it 'clones a new repository with JWT credentials' do
        expect(temp_repo).to receive(:clone_as_mirror)
                               .with(url_to_repo, http_authorization_header: anything)
                               .once
        expect(subject).to receive(:set_temp_repository_as_main)

        subject.execute
      end

      it 'cleans temporary repo after redownload' do
        expect(subject).to receive(:clone_geo_mirror).with(target_repository: temp_repo)
        expect(subject).to receive(:clean_up_temporary_repository).twice.and_call_original

        subject.execute
      end
    end
  end
end
