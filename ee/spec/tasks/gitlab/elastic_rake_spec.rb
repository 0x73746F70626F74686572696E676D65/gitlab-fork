# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:elastic namespace rake tasks', :elastic_helpers, :silence_stdout,
  feature_category: :global_search do
  before do
    Rake.application.rake_require 'tasks/gitlab/elastic'
  end

  shared_examples 'rake task executor task' do |task|
    it 'calls rake task executor' do
      expect_next_instance_of(Search::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(task)
      end

      run_rake_task("gitlab:elastic:#{task}")
    end
  end

  context 'when rake executor tasks' do
    Search::RakeTaskExecutorService::TASKS.each do |task|
      describe task do
        include_examples 'rake task executor task', task
      end
    end
  end

  describe 'gitlab:elastic:create_empty_index', :elastic_clean do
    subject(:task) { run_rake_task('gitlab:elastic:create_empty_index') }

    before do
      es_helper.delete_index
      es_helper.delete_standalone_indices
      es_helper.delete_migrations_index
    end

    it 'creates the default index' do
      expect { task }.to change { es_helper.index_exists? }.from(false).to(true)
    end

    context 'when SKIP_ALIAS environment variable is set' do
      before do
        stub_env('SKIP_ALIAS', '1')
      end

      after do
        es_helper.client.cat.indices(index: "#{es_helper.target_name}-*", h: 'index').split("\n").each do |index_name|
          es_helper.client.indices.delete(index: index_name)
        end
      end

      it 'does not alias the new index' do
        expect { task }.not_to change { es_helper.alias_exists?(name: es_helper.target_name) }
      end

      it 'does not create the migrations index if it does not exist' do
        migration_index_name = es_helper.migrations_index_name
        es_helper.delete_index(index_name: migration_index_name)

        expect { task }.not_to change { es_helper.index_exists?(index_name: migration_index_name) }
      end

      Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
        describe "for #{class_name}" do
          it "does not create a standalone index" do
            proxy = ::Elastic::Latest::ApplicationClassProxy.new(class_name, use_separate_indices: true)

            expect { task }.not_to change { es_helper.alias_exists?(name: proxy.index_name) }
          end
        end
      end
    end

    it 'creates the migrations index if it does not exist' do
      migration_index_name = es_helper.migrations_index_name
      es_helper.delete_index(index_name: migration_index_name)

      expect { task }.to change { es_helper.index_exists?(index_name: migration_index_name) }.from(false).to(true)
    end

    Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
      describe "for #{class_name}" do
        it "creates a standalone index" do
          proxy = ::Elastic::Latest::ApplicationClassProxy.new(class_name, use_separate_indices: true)
          expect { task }.to change { es_helper.index_exists?(index_name: proxy.index_name) }.from(false).to(true)
        end
      end
    end

    it 'marks all migrations as completed' do
      expect(Elastic::DataMigrationService).to receive(:mark_all_as_completed!).and_call_original

      task
      refresh_index!

      migrations = Elastic::DataMigrationService.migrations.map(&:version)
      expect(Elastic::MigrationRecord.load_versions(completed: true)).to eq(migrations)
    end
  end

  describe 'gitlab:elastic:delete_index', :elastic_clean do
    let(:logger) { Logger.new(StringIO.new) }
    let(:helper) { ::Gitlab::Elastic::Helper.default }

    subject(:task) { run_rake_task('gitlab:elastic:delete_index') }

    before do
      allow(main_object).to receive(:stdout_logger).and_return(logger)
      allow(logger).to receive(:info)
      allow(::Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
    end

    it 'removes the index' do
      expect { task }.to change { helper.index_exists? }.from(true).to(false)
    end

    context 'when delete_index returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_index).and_return(false)

        expect(logger).to receive(:info).with(%r{Index/alias '#{helper.target_name}' was not found})

        task
      end
    end

    it_behaves_like 'deletes all standalone indices'

    context 'when delete_standalone_indices returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_standalone_indices).and_return([['projects-123', 'projects', false]])

        expect(logger).to receive(:info).with(/Index 'projects-123' with alias 'projects' was not found/)

        task
      end
    end

    it 'removes the migrations index' do
      expect { task }.to change { es_helper.migrations_index_exists? }.from(true).to(false)
    end

    context 'when delete_migrations_index returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_migrations_index).and_return(false)

        expect(logger).to receive(:info).with(%r{Index/alias '#{es_helper.migrations_index_name}' was not found})

        task
      end
    end

    context 'when the index does not exist' do
      it 'does not error' do
        task
        task
      end
    end
  end

  context "with elasticsearch_indexing enabled", :elastic_clean do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    describe 'gitlab:elastic:index' do
      let(:logger) { Logger.new(StringIO.new) }

      before do
        allow(main_object).to receive(:stdout_logger).and_return(logger)
        allow(logger).to receive(:info)
      end

      subject(:task) { run_rake_task('gitlab:elastic:index') }

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { task }.to raise_error('This task cannot be run on GitLab.com')
        end
      end

      it 'schedules Search::Elastic::TriggerIndexingWorker asynchronously' do
        expect(Rake::Task['gitlab:elastic:recreate_index']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:clear_index_status']).to receive(:invoke).ordered

        expect(::Search::Elastic::TriggerIndexingWorker).to receive(:perform_in)
          .with(1.minute, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK, { 'skip' => 'projects' })

        task
      end

      it 'outputs warning if indexing is paused' do
        stub_ee_application_setting(elasticsearch_pause_indexing: true)

        expect(Rake::Task['gitlab:elastic:recreate_index']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:clear_index_status']).to receive(:invoke).ordered
        expect(::Search::Elastic::TriggerIndexingWorker).to receive(:perform_in)
          .with(1.minute, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK, { 'skip' => 'projects' })
        expect(logger).to receive(:warn).with(/WARNING: `elasticsearch_pause_indexing` is enabled/)

        task
      end

      context 'when elastic_index_use_trigger_indexing is disabled' do
        before do
          stub_feature_flags(elastic_index_use_trigger_indexing: false)
        end

        it 'calls all indexing tasks in order' do
          expect(Rake::Task['gitlab:elastic:recreate_index']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:clear_index_status']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_group_entities']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_projects']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_snippets']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_users']).to receive(:invoke).ordered

          task
        end

        it 'outputs warning if indexing is paused' do
          stub_ee_application_setting(elasticsearch_pause_indexing: true)

          expect(Rake::Task['gitlab:elastic:recreate_index']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:clear_index_status']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_group_entities']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_projects']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_snippets']).to receive(:invoke).ordered
          expect(Rake::Task['gitlab:elastic:index_users']).to receive(:invoke).ordered
          expect(logger).to receive(:warn).with(/WARNING: `elasticsearch_pause_indexing` is enabled/)

          task
        end
      end
    end

    describe 'gitlab:elastic:index_group_entities' do
      subject(:task) { run_rake_task('gitlab:elastic:index_group_entities') }

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { task }.to raise_error('This task cannot be run on GitLab.com')
        end
      end

      it 'calls all indexing tasks in order for the group entities' do
        expect(Rake::Task['gitlab:elastic:index_epics']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:index_group_wikis']).to receive(:invoke).ordered

        task
      end
    end

    describe 'gitlab:elastic:index_group_wikis' do
      let(:group1) { create(:group) }
      let(:group2) { create(:group) }
      let(:group3) { create(:group) }
      let(:subgrp) { create(:group, parent: group1) }
      let(:wiki1) { create(:group_wiki, group: group1) }
      let(:wiki2) { create(:group_wiki, group: group2) }
      let(:wiki3) { create(:group_wiki, group: group3) }
      let(:wiki4) { create(:group_wiki, group: subgrp) }

      subject(:task) { run_rake_task('gitlab:elastic:index_group_wikis') }

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { task }.to raise_error('This task cannot be run on GitLab.com')
        end
      end

      context 'with limited indexing disabled' do
        before do
          [wiki1, wiki2, wiki3, wiki4].each do |w|
            w.create_page('index_page', 'Bla bla term')
            w.index_wiki_blobs
          end
        end

        it 'calls ElasticWikiIndexerWorker for groups' do
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group1.id, group1.class.name, force: true)
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group2.id, group2.class.name, force: true)
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group3.id, group3.class.name, force: true)
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(subgrp.id, subgrp.class.name, force: true)

          task
        end
      end

      context 'with limited indexing enabled' do
        before do
          create(:elasticsearch_indexed_namespace, namespace: group1)
          create(:elasticsearch_indexed_namespace, namespace: group3)

          stub_ee_application_setting(elasticsearch_limit_indexing: true)

          [wiki1, wiki2, wiki3, wiki4].each do |w|
            w.create_page('index_page', 'Bla bla term')
            w.index_wiki_blobs
          end
        end

        it 'calls ElasticWikiIndexerWorker for groups which has elasticsearch enabled' do
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group1.id, group1.class.name, force: true)
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group3.id, group3.class.name, force: true)
          expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(subgrp.id, subgrp.class.name, force: true)
          expect(ElasticWikiIndexerWorker).not_to receive(:perform_async).with group2.id, group2.class.name, force: true

          task
        end
      end
    end

    describe 'gitlab:elastic:recreate_index' do
      it 'calls all related subtasks in order' do
        expect(Rake::Task['gitlab:elastic:delete_index']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:create_empty_index']).to receive(:invoke).ordered

        run_rake_task 'gitlab:elastic:recreate_index'
      end
    end
  end

  context "with elasticsearch_indexing is disabled" do
    describe 'gitlab:elastic:index' do
      it 'enables `elasticsearch_indexing`' do
        expect { run_rake_task 'gitlab:elastic:index' }.to change {
          Gitlab::CurrentSettings.elasticsearch_indexing?
        }.from(false).to(true)
      end
    end
  end

  describe 'gitlab:elastic:projects_not_indexed' do
    let!(:project) { create(:project, :repository) }
    let!(:project_no_repository) { create(:project) }
    let!(:project_empty_repository) { create(:project, :empty_repo) }
    let(:logger) { Logger.new(StringIO.new) }

    before do
      allow(main_object).to receive(:stdout_logger).and_return(logger)
      allow(logger).to receive(:info)
    end

    subject(:task) { run_rake_task('gitlab:elastic:projects_not_indexed') }

    context 'when projects missing from index' do
      it 'displays non-indexed projects' do
        expect(logger).to receive(:warn)
          .with("Project '#{project.full_path}' (ID: #{project.id}) isn't indexed.")
        expect(logger).to receive(:warn)
          .with("Project '#{project_no_repository.full_path}' (ID: #{project_no_repository.id}) isn't indexed.")
        expect(logger).to receive(:warn)
          .with("Project '#{project_empty_repository.full_path}' (ID: #{project_empty_repository.id}) isn't indexed.")
        expect(logger).to receive(:info).with("3 out of 3 non-indexed projects shown.")

        task
      end
    end

    context 'when all projects are indexed' do
      before do
        [project, project_no_repository, project_empty_repository].each do |p|
          create(:index_status, project: p)
        end
      end

      it 'displays that all projects are indexed' do
        expect(logger).to receive(:info).with(/All projects are currently indexed/)

        task
      end
    end
  end

  describe 'gitlab:elastic:info', :elastic do
    let(:settings) { ::Gitlab::CurrentSettings }
    let(:logger) { Logger.new(StringIO.new) }

    before do
      allow(main_object).to receive(:stdout_logger).and_return(logger)
      allow(logger).to receive(:info)
      settings.update!(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    subject(:task) { run_rake_task('gitlab:elastic:info') }

    it 'outputs server version' do
      expect(logger).to receive(:info).with(/Server version:\s+\d+.\d+.\d+/)

      task
    end

    it 'outputs server distribution' do
      expect(logger).to receive(:info).with(/Server distribution:\s+\w+/)

      task
    end

    it 'outputs indexing and search settings' do
      expected_regex = [
        /Indexing enabled:\s+yes/,
        /Search enabled:\s+yes/,
        /Requeue Indexing workers:\s+no/,
        /Pause indexing:\s+no/,
        /Indexing restrictions enabled:\s+no/
      ]

      expected_regex.each do |expected|
        expect(logger).to receive(:info).with(expected)
      end

      task
    end

    it 'outputs file size limit' do
      expect(logger).to receive(:info).with(/File size limit:\s+\d+ KiB/)

      task
    end

    it 'outputs indexing number of shards' do
      expect(logger).to receive(:info).with(/Indexing number of shards:\s+\d+/)

      task
    end

    it 'outputs max code indexing concurrency' do
      expect(logger).to receive(:info).with(/Max code indexing concurrency:\s+\d+/)

      task
    end

    it 'outputs queue sizes' do
      allow(Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(100)
      allow(Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(200)
      expect(logger).to receive(:info).with(/Initial queue:\s+100/)
      expect(logger).to receive(:info).with(/Incremental queue:\s+200/)

      task
    end

    it 'outputs pending migrations' do
      pending_migration = ::Elastic::DataMigrationService.migrations.last
      obsolete_migration = ::Elastic::DataMigrationService.migrations.first

      allow(pending_migration).to receive(:completed?).and_return(false)
      allow(obsolete_migration).to receive(:completed?).and_return(false)
      allow(obsolete_migration).to receive(:obsolete?).and_return(true)
      allow(::Elastic::DataMigrationService).to receive(:pending_migrations)
        .and_return([pending_migration, obsolete_migration])

      expect(logger).to receive(:info).with(/Pending Migrations/)
      expect(logger).to receive(:info).with(/#{pending_migration.name}/)
      expect(logger).to receive(:warn).with(/#{obsolete_migration.name} \[Obsolete\]/)

      task
    end

    it 'outputs current migration' do
      migration = ::Elastic::DataMigrationService.migrations.last
      allow(migration).to receive(:started?).and_return(true)
      allow(migration).to receive(:load_state).and_return({ test: 'value' })
      allow(Elastic::MigrationRecord).to receive(:current_migration).and_return(migration)

      expected_regex = [
        /Name:\s+#{migration.name}/,
        /Started:\s+yes/,
        /Halted:\s+no/,
        /Failed:\s+no/,
        /Obsolete:\s+no/,
        /Current state:\s+{"test":"value"}/
      ]

      expected_regex.each do |expected|
        expect(logger).to receive(:info).with(expected)
      end

      task
    end

    context 'with index settings' do
      let(:setting) do
        Elastic::IndexSetting.new(number_of_replicas: 1, number_of_shards: 8, alias_name: 'gitlab-development')
      end

      before do
        allow(Elastic::IndexSetting).to receive(:order).and_return([setting])
      end

      it 'outputs failed index setting' do
        allow(es_helper.client).to receive(:indices).and_raise(Timeout::Error)

        expect(logger).to receive(:error).with(/failed to load indices for gitlab-development/)

        task
      end

      it 'outputs index settings' do
        helper = Gitlab::Elastic::Helper.default
        allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
        allow(helper).to receive(:documents_count).and_return(1000)

        indices = instance_double(Elasticsearch::API::Indices::IndicesClient)
        allow(es_helper.client).to receive(:indices).and_return(indices)
        allow(indices).to receive(:stats).with(index: setting.alias_name).and_return({
          "indices" => {
            "index" => {
              "primaries" => {
                "docs" => {
                  "count" => 1000
                }
              }
            }
          }
        })
        allow(indices).to receive(:get_settings).with(index: setting.alias_name).and_return({
          setting.alias_name => {
            "settings" => {
              "index" => {
                "number_of_shards" => 5,
                "number_of_replicas" => 1,
                "refresh_interval" => '2s',
                "blocks" => {
                  "write" => 'true'
                }
              }
            }
          }
        })

        expected_regex = [/#{setting.alias_name}:/,
          /document_count: 1000/,
          /number_of_shards: 5/,
          /number_of_replicas: 1/,
          /refresh_interval: 2s/]

        expected_regex.each do |expected|
          expect(logger).to receive(:info).with(expected)
        end
        expect(logger).to receive(:error).with(/blocks.write: yes/)

        task
      end
    end

    context 'when the search client throws an error' do
      it 'logs an error message and does not raise an error' do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_raise(StandardError)

        expect(logger).to receive(:error).with(/An exception occurred during the retrieval of the data/)

        expect { task }.not_to raise_error
      end
    end
  end

  describe 'gitlab:elastic:clear_index_status' do
    it 'deletes all records for Elastic::GroupIndexStatus and IndexStatus tables' do
      expect(Elastic::GroupIndexStatus).to receive(:delete_all)
      expect(IndexStatus).to receive(:delete_all)

      run_rake_task('gitlab:elastic:clear_index_status')
    end
  end

  describe 'gitlab:elastic:disable_search_with_elasticsearch' do
    let(:settings) { ::Gitlab::CurrentSettings }

    subject(:task) { run_rake_task('gitlab:elastic:disable_search_with_elasticsearch') }

    context 'when elasticsearch_search is enabled' do
      it 'disables `elasticsearch_search`' do
        settings.update!(elasticsearch_search: true)

        expect { task }.to change { Gitlab::CurrentSettings.elasticsearch_search? }.from(true).to(false)
      end
    end

    context 'when elasticsearch_search is not enabled' do
      it 'does nothing' do
        settings.update!(elasticsearch_search: false)

        expect { task }.not_to change { Gitlab::CurrentSettings.elasticsearch_search? }
      end
    end
  end

  describe 'gitlab:elastic:enable_search_with_elasticsearch' do
    let(:settings) { ::Gitlab::CurrentSettings }

    subject(:task) { run_rake_task('gitlab:elastic:enable_search_with_elasticsearch') }

    context 'when elasticsearch_search is enabled' do
      it 'does nothing' do
        settings.update!(elasticsearch_search: true)

        expect { task }.not_to change { Gitlab::CurrentSettings.elasticsearch_search? }
      end
    end

    context 'when elasticsearch_search is not enabled' do
      it 'enables `elasticsearch_search`' do
        settings.update!(elasticsearch_search: false)

        expect { task }.to change { Gitlab::CurrentSettings.elasticsearch_search? }.from(false).to(true)
      end
    end
  end

  describe 'gitlab:elastic:reindex_cluster' do
    let(:logger) { Logger.new(StringIO.new) }

    before do
      allow(main_object).to receive(:stdout_logger).and_return(logger)
      allow(logger).to receive(:info)
    end

    subject(:task) { run_rake_task('gitlab:elastic:reindex_cluster') }

    it 'creates a reindexing task and queues the cron worker' do
      expect(::Elastic::ReindexingTask).to receive(:create!)
      expect(::ElasticClusterReindexingCronWorker).to receive(:perform_async)

      expect(logger).to receive(:info).with(/Reindexing job was successfully scheduled/)

      task
    end

    context 'when a reindexing task is in progress' do
      it 'logs an error' do
        expect(::Elastic::ReindexingTask).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
        expect(::ElasticClusterReindexingCronWorker).not_to receive(:perform_async)

        expect(logger).to receive(:error).with(/There is another task in progress. Please wait for it to finish/)

        task
      end
    end
  end
end
