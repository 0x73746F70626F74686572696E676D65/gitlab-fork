# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::Indexer, feature_category: :global_search do
  include StubENV

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'true')
  end

  let(:project) { create(:project, :repository) }
  let(:user) { project.first_owner }

  let(:expected_from_sha) { Gitlab::Git::SHA1_EMPTY_TREE_ID }
  let(:to_commit) { project.commit }
  let(:to_sha) { to_commit.try(:sha) }

  let(:popen_success) { [[''], 0] }
  let(:popen_failure) { [['error'], 1] }

  let(:force_reindexing) { false }

  subject(:indexer) { described_class.new(project, force: force_reindexing) }

  context 'empty project', :elastic do
    let_it_be_with_reload(:project) { create(:project, :empty_repo) }

    it 'updates the index status without running the indexing command' do
      expect_popen.never

      indexer.run

      expect_index_status(Gitlab::Git::SHA1_BLANK_SHA)
    end

    context 'when indexing a project with no repository' do
      it 'updates the index status without running the indexing command' do
        allow(project.repository).to receive(:exists?).and_return(false)
        expect_popen.never

        indexer.run

        expect_index_status(Gitlab::Git::SHA1_BLANK_SHA)
      end
    end

    context 'when fresh master branch is first pushed, followed by another update, then indexed' do
      it 'indexes initial push' do
        sha1 = project.repository.create_file(user, '12', '', message: '12', branch_name: 'master')
        project.repository.create_file(user, '23', '', message: '23', branch_name: 'master')

        described_class.new(project).run(sha1)

        ensure_elasticsearch_index!

        expect(indexed_file_paths_for('12')).to include('12')
        expect(indexed_file_paths_for('23')).not_to include('23')
      end
    end
  end

  describe '#find_indexable_commit' do
    it 'returns a commit for reachable commits' do
      expect(indexer.find_indexable_commit(project.repository.commit.sha)).to eq(project.repository.commit)
    end

    it 'returns nil for unreachable commits', :aggregate_failures do
      expect(indexer.find_indexable_commit(Gitlab::Git::SHA1_BLANK_SHA)).to be_nil
      expect(indexer.find_indexable_commit(Gitlab::Git::SHA1_EMPTY_TREE_ID)).to be_nil
    end

    context 'when repository project is empty' do
      let_it_be(:project) { create(:project, :empty_repo) }

      it 'returns nil' do
        expect(indexer.find_indexable_commit('HEAD')).to be_nil
      end
    end

    context 'when ref is nil' do
      it 'returns the commit from the default branch' do
        expect(indexer.find_indexable_commit(nil)).to eq(project.repository.commit)
      end
    end

    context 'when specific ref is requested' do
      context 'when ref exists' do
        it 'returns the commit' do
          expect(indexer.find_indexable_commit('test')).to eq(project.repository.commit('test'))
        end
      end

      context 'when ref does not exist' do
        it 'returns nil' do
          expect(indexer.find_indexable_commit('does-not-exist')).to be_nil
        end
      end
    end
  end

  describe '#purge_unreachable_commits_from_index?' do
    using RSpec::Parameterized::TableSyntax

    where(:to_sha, :force_reindexing, :ancestor_of, :result) do
      'commit_sha'  | true  | true  | true
      'commit_sha'  | true  | false | true
      'commit_sha'  | false | true  | false
      'commit_sha'  | false | false | true
      nil           | true  | true  | true
      nil           | true  | false | true
      nil           | false | true  | true
      nil           | false | false | true
    end

    with_them do
      it 'returns correct result' do
        allow(indexer).to receive(:last_commit_ancestor_of?).and_return(ancestor_of)

        expect(indexer.purge_unreachable_commits_from_index?(to_sha)).to eq(result)
      end
    end
  end

  context 'with an indexed project', :elastic do
    let(:to_sha) { project.repository.commit.sha }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    shared_examples 'index up to the specified commit' do
      it 'updates the index status when the indexing is a success' do
        expect_popen.and_return(popen_success)

        indexer.run(to_sha)

        expect_index_status(to_sha)
      end

      it 'leaves the index status untouched when the indexing fails' do
        expect_popen.and_return(popen_failure)

        expect { indexer.run }.to raise_error(Gitlab::Elastic::Indexer::Error)

        expect(project.index_status).to be_nil
      end
    end

    context 'when indexing a HEAD commit', :elastic do
      it_behaves_like 'index up to the specified commit'

      context 'when search curation is disabled' do
        before do
          stub_feature_flags(search_index_curation: false)
        end

        it 'runs the indexing command without --search-curation flag' do
          gitaly_connection_data = {
            storage: project.repository_storage,
            limit_file_size: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes
          }.merge(Gitlab::GitalyClient.connection_data(project.repository_storage))

          expect_popen.with(
            [
              TestEnv.indexer_bin_path,
              "--timeout=#{described_class::TIMEOUT}s",
              "--visibility-level=#{project.visibility_level}",
              "--project-id=#{project.id}",
              "--from-sha=#{expected_from_sha}",
              "--to-sha=#{to_sha}",
              "--full-path=#{project.full_path}",
              "--repository-access-level=#{project.repository_access_level}",
              "--hashed-root-namespace-id=#{project.namespace.hashed_root_namespace_id}",
              "--schema-version-blob=2308",
              "--schema-version-commit=2306",
              "--archived=#{project.archived}",
              "--traversal-ids=#{project.namespace_ancestry}",
              "#{project.repository.disk_path}.git"
            ],
            nil,
            hash_including(
              'GITALY_CONNECTION_INFO' => gitaly_connection_data.to_json,
              'ELASTIC_CONNECTION_INFO' => elasticsearch_config.to_json,
              'RAILS_ENV' => Rails.env,
              'CORRELATION_ID' => Labkit::Correlation::CorrelationId.current_id
            )
          ).and_return(popen_success)

          indexer.run
        end
      end

      it 'runs the indexing command' do
        gitaly_connection_data = {
          storage: project.repository_storage,
          limit_file_size: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes
        }.merge(Gitlab::GitalyClient.connection_data(project.repository_storage))

        expect_popen.with(
          [
            TestEnv.indexer_bin_path,
            "--timeout=#{described_class::TIMEOUT}s",
            "--visibility-level=#{project.visibility_level}",
            "--project-id=#{project.id}",
            '--search-curation',
            "--from-sha=#{expected_from_sha}",
            "--to-sha=#{to_sha}",
            "--full-path=#{project.full_path}",
            "--repository-access-level=#{project.repository_access_level}",
            "--hashed-root-namespace-id=#{project.namespace.hashed_root_namespace_id}",
            "--schema-version-blob=2308",
            "--schema-version-commit=2306",
            "--archived=#{project.archived}",
            "--traversal-ids=#{project.namespace_ancestry}",
            "#{project.repository.disk_path}.git"
          ],
          nil,
          hash_including(
            'GITALY_CONNECTION_INFO' => gitaly_connection_data.to_json,
            'ELASTIC_CONNECTION_INFO' => elasticsearch_config.to_json,
            'RAILS_ENV' => Rails.env,
            'CORRELATION_ID' => Labkit::Correlation::CorrelationId.current_id
          )
        ).and_return(popen_success)

        indexer.run
      end

      context 'when IndexStatus exists' do
        context 'when last_commit exists' do
          let(:last_commit) { to_commit.parent_ids.first }

          before do
            project.create_index_status!(last_commit: last_commit)
          end

          it 'uses last_commit as from_sha' do
            expect_popen.and_return(popen_success)

            indexer.run(to_sha)

            expect_index_status(to_sha)
          end
        end
      end
    end

    context 'when indexing a non-HEAD commit', :elastic do
      let(:to_sha) { project.repository.commit('HEAD~1').sha }

      it_behaves_like 'index up to the specified commit'

      context 'after reverting a change' do
        let!(:initial_commit) { project.repository.commit('master').sha }

        def indexed_commits_for(term)
          commits = Repository.elastic_search(
            term,
            type: 'commit'
          )[:commits][:results].response

          commits.map do |commit|
            commit['_source']['sha']
          end
        end

        context 'when IndexStatus#last_commit is no longer in repository' do
          it 'reindexes from scratch' do
            sha_for_reset = nil

            change_repository_and_index(project) do
              sha_for_reset = project.repository.create_file(user, '12', '', message: '12', branch_name: 'master')
              project.repository.create_file(user, '23', '', message: '23', branch_name: 'master')
            end

            expect(indexed_file_paths_for('12')).to include('12')
            expect(indexed_file_paths_for('23')).to include('23')

            project.index_status.update!(last_commit: '____________')

            change_repository_and_index(project) do
              project.repository.write_ref('master', sha_for_reset)
            end

            expect(indexed_file_paths_for('12')).to include('12')
            expect(indexed_file_paths_for('23')).not_to include('23')
          end
        end

        context 'when branch is reset to an earlier commit' do
          it 'reverses already indexed commits' do
            change_repository_and_index(project) do
              project.repository.create_file(user, '24', '', message: '24', branch_name: 'master')
            end

            head = project.repository.commit.sha

            expect(indexed_commits_for('24')).to include(head)
            expect(indexed_file_paths_for('24')).to include('24')

            # resetting the repository should purge the index of the outstanding commits
            change_repository_and_index(project) do
              project.repository.write_ref('master', initial_commit)
            end

            expect(indexed_commits_for('24')).not_to include(head)
            expect(indexed_file_paths_for('24')).not_to include('24')
          end
        end
      end
    end

    context "when indexing a project's wiki", :elastic do
      let_it_be_with_reload(:project) { create(:project, :wiki_repo) }

      let(:indexer) { described_class.new(project, wiki: true) }
      let(:to_sha) { project.wiki.repository.commit('master').sha }

      before do
        project.wiki.create_page('test.md', '# term')
      end

      context 'when search curation is disabled' do
        before do
          stub_feature_flags(search_index_curation: false)
        end

        it 'runs the indexer with the right flags without --search-curation' do
          expect_popen.with(
            [
              TestEnv.indexer_bin_path,
              "--timeout=#{described_class::TIMEOUT}s",
              "--visibility-level=#{project.visibility_level}",
              "--project-id=#{project.id}",
              "--from-sha=#{expected_from_sha}",
              "--to-sha=#{to_sha}",
              "--full-path=#{project.full_path}",
              '--blob-type=wiki_blob',
              '--skip-commits',
              "--wiki-access-level=#{project.wiki_access_level}",
              "--archived=false",
              "--schema-version-wiki=#{described_class::WIKI_SCHEMA_VERSION}",
              "--traversal-ids=#{project.namespace_ancestry}",
              "#{project.wiki.repository.disk_path}.git"
            ],
            nil,
            hash_including(
              'ELASTIC_CONNECTION_INFO' => elasticsearch_config.to_json,
              'RAILS_ENV' => Rails.env
            )
          ).and_return(popen_success)

          indexer.run
        end
      end

      it 'runs the indexer with the right flags' do
        expect_popen.with(
          [
            TestEnv.indexer_bin_path,
            "--timeout=#{described_class::TIMEOUT}s",
            "--visibility-level=#{project.visibility_level}",
            "--project-id=#{project.id}",
            '--search-curation',
            "--from-sha=#{expected_from_sha}",
            "--to-sha=#{to_sha}",
            "--full-path=#{project.full_path}",
            '--blob-type=wiki_blob',
            '--skip-commits',
            "--wiki-access-level=#{project.wiki_access_level}",
            "--archived=false",
            "--schema-version-wiki=#{described_class::WIKI_SCHEMA_VERSION}",
            "--traversal-ids=#{project.namespace_ancestry}",
            "#{project.wiki.repository.disk_path}.git"
          ],
          nil,
          hash_including(
            'ELASTIC_CONNECTION_INFO' => elasticsearch_config.to_json,
            'RAILS_ENV' => Rails.env
          )
        ).and_return(popen_success)

        indexer.run
      end

      context 'when IndexStatus#last_wiki_commit is no longer in repository' do
        it 'reindexes from scratch' do
          sha_for_reset = nil

          change_wiki_and_index(project) do
            sha_for_reset = project.wiki.repository.create_file(user, '12.md', '', message: '12', branch_name: 'master')
            project.wiki.repository.create_file(user, '23.md', '', message: '23', branch_name: 'master')
          end
          expect(indexed_wiki_paths_for('12')).to include('12.md')
          expect(indexed_wiki_paths_for('23')).to include('23.md')

          project.index_status.update!(last_wiki_commit: '____________')

          change_wiki_and_index(project) do
            project.wiki.repository.write_ref('master', sha_for_reset)
          end

          expect(indexed_wiki_paths_for('12')).to include('12.md')
          expect(indexed_wiki_paths_for('23')).not_to include('23.md')
        end
      end

      context 'when add_archived_to_wikis migration is not completed' do
        before do
          set_elasticsearch_migration_to(:add_archived_to_wikis, including: false)
        end

        it 'runs the indexer without --archived flag' do
          gitaly_connection_data = {
            storage: project.repository_storage,
            limit_file_size: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes
          }.merge(Gitlab::GitalyClient.connection_data(project.repository_storage))
          expect_popen.with(
            [
              TestEnv.indexer_bin_path,
              "--timeout=#{described_class::TIMEOUT}s",
              "--visibility-level=#{project.visibility_level}",
              "--project-id=#{project.id}",
              '--search-curation',
              "--from-sha=#{expected_from_sha}",
              "--to-sha=#{to_sha}",
              "--full-path=#{project.full_path}",
              '--blob-type=wiki_blob',
              '--skip-commits',
              "--wiki-access-level=#{project.wiki_access_level}",
              "--schema-version-wiki=#{described_class::WIKI_SCHEMA_VERSION}",
              "--traversal-ids=#{project.namespace_ancestry}",
              "#{project.wiki.repository.disk_path}.git"
            ],
            nil,
            hash_including(
              'GITALY_CONNECTION_INFO' => gitaly_connection_data.to_json,
              'ELASTIC_CONNECTION_INFO' => elasticsearch_config.to_json,
              'RAILS_ENV' => Rails.env,
              'CORRELATION_ID' => Labkit::Correlation::CorrelationId.current_id
            )
          ).and_return(popen_success)

          indexer.run
        end
      end
    end
  end

  context "when indexing a group's wiki", :elastic do
    let_it_be(:wiki) { create(:group_wiki) }
    let(:group) { wiki.container }

    let(:indexer) { described_class.new(group, wiki: true) }
    let(:to_sha) { group.wiki.repository.commit('master').sha }

    before do
      wiki.create_page('test.md', '# Test')
    end

    it 'runs the indexer with the right flags' do
      expect_popen.with(
        [
          TestEnv.indexer_bin_path,
          "--timeout=#{described_class::TIMEOUT}s",
          "--visibility-level=#{group.visibility_level}",
          "--group-id=#{group.id}",
          '--search-curation',
          "--from-sha=#{expected_from_sha}",
          "--to-sha=#{to_sha}",
          "--full-path=#{group.full_path}",
          '--blob-type=wiki_blob',
          '--skip-commits',
          "--wiki-access-level=#{group.wiki_access_level}",
          "--schema-version-wiki=#{described_class::WIKI_SCHEMA_VERSION}",
          "--traversal-ids=#{group.elastic_namespace_ancestry}",
          "#{group.wiki.repository.disk_path}.git"
        ], nil, hash_including('ELASTIC_CONNECTION_INFO' => elasticsearch_config.to_json, 'RAILS_ENV' => Rails.env)
      ).and_return(popen_success)

      indexer.run
    end
  end

  context 'when SSL env vars are not set explicitly' do
    let(:ruby_cert_file) { OpenSSL::X509::DEFAULT_CERT_FILE }
    let(:ruby_cert_dir) { OpenSSL::X509::DEFAULT_CERT_DIR }

    subject { envvars }

    it 'they will be set to default values determined by Ruby' do
      is_expected.to include('SSL_CERT_FILE' => ruby_cert_file, 'SSL_CERT_DIR' => ruby_cert_dir)
    end
  end

  context 'when SSL env vars are set' do
    let(:cert_file) { '/fake/cert.pem' }
    let(:cert_dir) { '/fake/cert/dir' }

    before do
      allow(ENV).to receive(:slice).with('SSL_CERT_FILE', 'SSL_CERT_DIR').and_return({
        'SSL_CERT_FILE' => cert_file,
        'SSL_CERT_DIR' => cert_dir
      })
    end

    context 'when building env vars for child process' do
      subject { envvars }

      it 'SSL env vars will be included' do
        is_expected.to include('SSL_CERT_FILE' => cert_file, 'SSL_CERT_DIR' => cert_dir)
      end
    end
  end

  context 'when no aws credentials available' do
    subject { envvars }

    before do
      allow(Gitlab::Elastic::Client).to receive(:aws_credential_provider).and_return(nil)
    end

    it 'credentials env vars will not be included' do
      expect(subject).not_to include('AWS_ACCESS_KEY_ID')
      expect(subject).not_to include('AWS_SECRET_ACCESS_KEY')
      expect(subject).not_to include('AWS_SESSION_TOKEN')
    end
  end

  context 'when aws credentials are available' do
    let(:access_key_id) { '012' }
    let(:secret_access_key) { 'secret' }
    let(:session_token) { 'token' }
    let(:credentials) { Aws::Credentials.new(access_key_id, secret_access_key, session_token) }

    subject { envvars }

    context 'when AWS config is not enabled' do
      it 'credentials env vars will not be included' do
        expect(subject).not_to include('AWS_ACCESS_KEY_ID')
        expect(subject).not_to include('AWS_SECRET_ACCESS_KEY')
        expect(subject).not_to include('AWS_SESSION_TOKEN')
      end
    end

    context 'when AWS config is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_aws: true)
      end

      it 'credentials env vars will be included' do
        expect(Gitlab::Elastic::Client).to receive(:resolve_aws_credentials).and_call_original

        expect_next_instance_of(Aws::CredentialProviderChain) do |chain|
          expect(chain).to receive(:resolve).and_return(credentials)
        end

        expect(subject).to include({
          'AWS_ACCESS_KEY_ID' => access_key_id,
          'AWS_SECRET_ACCESS_KEY' => secret_access_key,
          'AWS_SESSION_TOKEN' => session_token
        })
      end

      context 'when static credentials are set' do
        before do
          stub_ee_application_setting(elasticsearch_aws_access_key: access_key_id)
          stub_ee_application_setting(elasticsearch_aws_secret_access_key: secret_access_key)
        end

        it 'uses static credentials to set env vars' do
          expect(Gitlab::Elastic::Client).to receive(:resolve_aws_credentials).and_call_original
          expect(Aws::CredentialProviderChain).not_to receive(:new)

          expect(subject).to include({
            'AWS_ACCESS_KEY_ID' => access_key_id,
            'AWS_SECRET_ACCESS_KEY' => secret_access_key,
            'AWS_SESSION_TOKEN' => nil
          })
        end
      end
    end
  end

  context 'when a file is larger than elasticsearch_indexed_file_size_limit_kb', :elastic do
    before do
      stub_ee_application_setting(elasticsearch_indexed_file_size_limit_kb: 1) # 1 KiB limit

      project.repository.create_file(user, 'small_file.txt', 'Small file contents', message: 'small_file.txt', branch_name: 'master')
      project.repository.create_file(user, 'large_file.txt', 'Large file' * 1000, message: 'large_file.txt', branch_name: 'master')

      index_repository(project)
    end

    it 'indexes the file with empty content' do
      files = indexed_file_paths_for('file')
      expect(files).to include('small_file.txt', 'large_file.txt')

      blobs = Repository.elastic_search('large_file', type: 'blob')[:blobs][:results].response
      large_file_blob = blobs.find do |blob|
        'large_file.txt' == blob['_source']['blob']['path']
      end
      expect(large_file_blob['_source']['blob']['content']).to eq('')
    end
  end

  context 'when a file path is larger than elasticsearch max size of 512 bytes', :elastic do
    let(:long_path) { "#{'a' * 1000}_file.txt" }

    before do
      project.repository.create_file(user, long_path, 'Large path file contents', message: 'long_path.txt', branch_name: 'master')

      index_repository(project)
    end

    it 'indexes the file' do
      files = indexed_file_paths_for('file')
      expect(files).to include(long_path)
    end
  end

  context 'when project no longer exists in database' do
    let(:logger_double) { instance_double(Gitlab::Elasticsearch::Logger) }

    before do
      allow(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double)
      allow(indexer).to receive(:run_indexer!) { Project.where(id: project.id).delete_all }
      allow(indexer).to receive(:purge_unreachable_commits_from_index?).and_return(false)
      allow(logger_double).to receive(:debug)
    end

    it 'does not raise an exception and prints log message' do
      expect(logger_double).to receive(:debug).with(
        {
          'class' => 'Gitlab::Elastic::Indexer',
          'message' => 'Index status not updated. The project does not exist.',
          'project_id' => project.id,
          'index_wiki' => false,
          'group_id' => project.group
        }
      )
      expect(IndexStatus).not_to receive(:safe_find_or_create_by!).with(project_id: project.id)
      expect { indexer.run }.not_to raise_error
    end
  end

  context 'when IndexStatus.safe_find_or_create_by! throws an InvalidForeignKey exception' do
    let(:logger_double) { instance_double(Gitlab::Elasticsearch::Logger) }

    before do
      allow(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double)
      allow(indexer).to receive(:run_indexer!)
      allow(indexer).to receive(:purge_unreachable_commits_from_index?).and_return(false)
      allow(logger_double).to receive(:debug)
    end

    it 'does not raise an exception and prints a log message' do
      expect(logger_double).to receive(:debug).with(
        {
          'class' => 'Gitlab::Elastic::Indexer',
          'message' => 'Index status not created, project not found',
          'project_id' => project.id,
          'group_id' => project.group
        }
      )

      allow(IndexStatus).to receive(:safe_find_or_create_by!).and_raise(ActiveRecord::InvalidForeignKey)

      expect { indexer.run }.not_to raise_error
    end
  end

  context 'when purge_unreachable_commits_from_index? is true', :elastic do
    context 'when deleting index raise BadRequest' do
      before do
        allow(indexer).to receive(:purge_unreachable_commits_from_index?).and_return(true)
        allow_next_instance_of(Elastic::Latest::RepositoryInstanceProxy) do |instance|
          allow(instance).to receive(:delete_index_for_commits_and_blobs).and_raise Elasticsearch::Transport::Transport::Errors::BadRequest
        end
      end

      it 'calls track_exception on Gitlab::ErrorTracking' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(Elasticsearch::Transport::Transport::Errors::BadRequest, group_id: project.group, project_id: project.id)
        indexer.run
      end
    end
  end

  describe 'integration test', :elastic do
    context 'for blobs' do
      it 'correctly indexes commits which add and remove files' do
        filename_1 = 'test-1.md'
        filename_2 = 'test-2.md'
        branch = project.default_branch

        change_repository_and_index(project) do
          project.repository.create_file(user, filename_1, '', message: "adding #{filename_1}", branch_name: branch)
          project.repository.create_file(user, filename_2, '', message: "adding #{filename_2}", branch_name: branch)
        end

        expect(indexed_file_paths_for(filename_1)).to include(filename_1)
        expect(indexed_file_paths_for(filename_2)).to include(filename_2)

        change_repository_and_index(project) do
          project.repository.update_file(user, filename_1, '', message: "#{filename_1} updated", branch_name: branch)
          project.repository.delete_file(user, filename_2, message: "remove #{filename_2}", branch_name: branch)
        end

        expect(indexed_file_paths_for(filename_1)).to include(filename_1)
        expect(indexed_file_paths_for(filename_2)).not_to include(filename_2)
      end
    end

    context 'for wiki blobs' do
      let_it_be(:project) { create(:project, :wiki_repo) }

      it 'correctly indexes commits which add and remove files' do
        filename_1 = 'test-1.md'
        filename_2 = 'test-2.md'
        branch = project.wiki.default_branch

        change_wiki_and_index(project) do
          project.wiki.repository.create_file(user, filename_1, '', message: "adding #{filename_1}", branch_name: branch)
          project.wiki.repository.create_file(user, filename_2, '', message: "adding #{filename_2}", branch_name: branch)
        end

        expect(indexed_wiki_paths_for(filename_1)).to include(filename_1)
        expect(indexed_wiki_paths_for(filename_2)).to include(filename_2)

        change_wiki_and_index(project) do
          project.wiki.repository.update_file(user, filename_1, '', message: "#{filename_1} updated", branch_name: branch)
          project.wiki.repository.delete_file(user, filename_2, message: "remove #{filename_2}", branch_name: branch)
        end

        expect(indexed_wiki_paths_for(filename_1)).to include(filename_1)
        expect(indexed_wiki_paths_for(filename_2)).not_to include(filename_2)
      end
    end
  end

  def expect_popen
    expect(Gitlab::Popen).to receive(:popen)
  end

  def expect_index_status(sha)
    status = project.index_status

    expect(status).not_to be_nil
    expect(status.indexed_at).not_to be_nil
    expect(status.last_commit).to eq(sha)
  end

  def elasticsearch_config
    Gitlab::CurrentSettings.elasticsearch_config.merge(
      index_name: 'gitlab-test',
      index_name_commits: 'gitlab-test-commits',
      index_name_wikis: 'gitlab-test-wikis'
    ).tap do |config|
      config[:url] = config[:url].map { |u| ::Gitlab::Elastic::Helper.url_string(u) }
    end
  end

  def envvars
    indexer.send(:build_envvars, project.repository.__elasticsearch__.elastic_writing_targets.first)
  end

  def indexed_file_paths_for(term)
    blobs = Repository.elastic_search(
      term,
      type: 'blob'
    )[:blobs][:results].response

    blobs.map do |blob|
      blob['_source']['blob']['path']
    end
  end

  def index_repository(project)
    current_commit = project.repository.commit('master').sha

    described_class.new(project).run(current_commit)
    ensure_elasticsearch_index!
  end

  def change_repository_and_index(project, &blk)
    yield blk if blk

    index_repository(project)
  end

  def change_wiki_and_index(project, &blk)
    yield blk if blk

    current_commit = project.wiki.repository.commit('master').sha

    described_class.new(project, wiki: true).run(current_commit)
    ensure_elasticsearch_index!
  end

  def indexed_wiki_paths_for(term)
    blobs = ProjectWiki.elastic_search(term, type: 'wiki_blob')[:wiki_blobs][:results].response
    blobs.map { |blob| blob['_source']['path'] }
  end
end
