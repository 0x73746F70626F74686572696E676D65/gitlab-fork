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

  describe 'create_empty_index', :elastic_clean do
    subject { run_rake_task('gitlab:elastic:create_empty_index') }

    before do
      es_helper.delete_index
      es_helper.delete_standalone_indices
      es_helper.delete_migrations_index
    end

    it 'creates the default index' do
      expect { subject }.to change { es_helper.index_exists? }.from(false).to(true)
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
        expect { subject }.not_to change { es_helper.alias_exists?(name: es_helper.target_name) }
      end

      it 'does not create the migrations index if it does not exist' do
        migration_index_name = es_helper.migrations_index_name
        es_helper.delete_index(index_name: migration_index_name)

        expect { subject }.not_to change { es_helper.index_exists?(index_name: migration_index_name) }
      end

      Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
        describe class_name do
          it "does not create a standalone index" do
            proxy = ::Elastic::Latest::ApplicationClassProxy.new(class_name, use_separate_indices: true)

            expect { subject }.not_to change { es_helper.alias_exists?(name: proxy.index_name) }
          end
        end
      end
    end

    it 'creates the migrations index if it does not exist' do
      migration_index_name = es_helper.migrations_index_name
      es_helper.delete_index(index_name: migration_index_name)

      expect { subject }.to change { es_helper.index_exists?(index_name: migration_index_name) }.from(false).to(true)
    end

    Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
      describe class_name do
        it "creates a standalone index" do
          proxy = ::Elastic::Latest::ApplicationClassProxy.new(class_name, use_separate_indices: true)
          expect { subject }.to change { es_helper.index_exists?(index_name: proxy.index_name) }.from(false).to(true)
        end
      end
    end

    it 'marks all migrations as completed' do
      expect(Elastic::DataMigrationService).to receive(:mark_all_as_completed!).and_call_original

      subject
      refresh_index!

      migrations = Elastic::DataMigrationService.migrations.map(&:version)
      expect(Elastic::MigrationRecord.load_versions(completed: true)).to eq(migrations)
    end
  end

  describe 'delete_index', :elastic_clean do
    subject { run_rake_task('gitlab:elastic:delete_index') }

    it 'removes the index' do
      expect { subject }.to change { es_helper.index_exists? }.from(true).to(false)
    end

    it_behaves_like 'deletes all standalone indices' do
      let(:helper) { es_helper }
    end

    it 'removes the migrations index' do
      expect { subject }.to change { es_helper.migrations_index_exists? }.from(true).to(false)
    end

    context 'when the index does not exist' do
      it 'does not error' do
        run_rake_task('gitlab:elastic:delete_index')
        run_rake_task('gitlab:elastic:delete_index')
      end
    end
  end

  context "with elasticsearch_indexing enabled", :elastic_clean do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    describe 'index' do
      subject { run_rake_task('gitlab:elastic:index') }

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { subject }.to raise_error('This task cannot be run on GitLab.com')
        end
      end

      it 'calls all indexing tasks in order' do
        expect(Rake::Task['gitlab:elastic:recreate_index']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:clear_index_status']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:index_group_entities']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:index_projects']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:index_snippets']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:index_users']).to receive(:invoke).ordered

        subject
      end

      it 'outputs warning if indexing is paused' do
        stub_ee_application_setting(elasticsearch_pause_indexing: true)

        expect { subject }.to output(/WARNING: `elasticsearch_pause_indexing` is enabled/).to_stdout
      end
    end

    describe 'index_group_entities' do
      subject { run_rake_task('gitlab:elastic:index_group_entities') }

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { subject }.to raise_error('This task cannot be run on GitLab.com')
        end
      end

      it 'calls all indexing tasks in order for the group entities' do
        expect(Rake::Task['gitlab:elastic:index_epics']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:index_group_wikis']).to receive(:invoke).ordered

        subject
      end
    end

    describe 'index_group_wikis' do
      let(:group1) { create(:group) }
      let(:group2) { create(:group) }
      let(:group3) { create(:group) }
      let(:subgrp) { create(:group, parent: group1) }
      let(:wiki1) { create(:group_wiki, group: group1) }
      let(:wiki2) { create(:group_wiki, group: group2) }
      let(:wiki3) { create(:group_wiki, group: group3) }
      let(:wiki4) { create(:group_wiki, group: subgrp) }

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { run_rake_task('gitlab:elastic:index') }.to raise_error('This task cannot be run on GitLab.com')
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
          run_rake_task 'gitlab:elastic:index_group_wikis'
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
          run_rake_task 'gitlab:elastic:index_group_wikis'
        end
      end
    end

    describe 'recreate_index' do
      it 'calls all related subtasks in order' do
        expect(Rake::Task['gitlab:elastic:delete_index']).to receive(:invoke).ordered
        expect(Rake::Task['gitlab:elastic:create_empty_index']).to receive(:invoke).ordered

        run_rake_task 'gitlab:elastic:recreate_index'
      end
    end
  end

  context "with elasticsearch_indexing is disabled" do
    it 'enables `elasticsearch_indexing`' do
      expect { run_rake_task 'gitlab:elastic:index' }.to change {
        Gitlab::CurrentSettings.elasticsearch_indexing?
      }.from(false).to(true)
    end
  end

  describe 'projects_not_indexed' do
    subject { run_rake_task('gitlab:elastic:projects_not_indexed') }

    let!(:project) { create(:project, :repository) }
    let!(:project_no_repository) { create(:project) }
    let!(:project_empty_repository) { create(:project, :empty_repo) }

    context 'when projects missing from index' do
      it 'displays non-indexed projects' do
        expected = <<~STD_OUT
          Project '#{project.full_path}' (ID: #{project.id}) isn't indexed.
          Project '#{project_no_repository.full_path}' (ID: #{project_no_repository.id}) isn't indexed.
          Project '#{project_empty_repository.full_path}' (ID: #{project_empty_repository.id}) isn't indexed.
          3 out of 3 non-indexed projects shown.
        STD_OUT

        expect { subject }.to output(expected).to_stdout
      end
    end

    context 'when all projects are indexed' do
      before do
        [project, project_no_repository, project_empty_repository].each do |p|
          create(:index_status, project: p)
        end
      end

      it 'displays that all projects are indexed' do
        expect { subject }.to output(/All projects are currently indexed/).to_stdout
      end
    end
  end

  describe 'info', :elastic do
    subject { run_rake_task('gitlab:elastic:info') }

    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      settings.update!(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    it 'outputs server version' do
      expect { subject }.to output(/Server version:\s+\d+.\d+.\d+/).to_stdout
    end

    it 'outputs server distribution' do
      expect { subject }.to output(/Server distribution:\s+\w+/).to_stdout
    end

    it 'outputs indexing and search settings' do
      expected_regex = Regexp.new([
        'Indexing enabled:\\s+yes\\s+',
        'Search enabled:\\s+yes\\s+',
        'Requeue Indexing workers:\\s+no\\s+',
        'Pause indexing:\\s+no\\s+',
        'Indexing restrictions enabled:\\s+no\\s+'
      ].join(''))
      expect { subject }.to output(expected_regex).to_stdout
    end

    it 'outputs file size limit' do
      expect { subject }.to output(/File size limit:\s+\d+ KiB/).to_stdout
    end

    it 'outputs indexing number of shards' do
      expect { subject }.to output(/Indexing number of shards:\s+\d+/).to_stdout
    end

    it 'outputs queue sizes' do
      allow(Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(100)
      allow(Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(200)

      expect { subject }.to output(/Initial queue:\s+100\s+Incremental queue:\s+200/).to_stdout
    end

    it 'outputs pending migrations' do
      pending_migration = ::Elastic::DataMigrationService.migrations.last
      obsolete_migration = ::Elastic::DataMigrationService.migrations.first
      pending_migration.save!(completed: false)
      obsolete_migration.save!(completed: false)

      allow(::Elastic::DataMigrationService).to receive(:pending_migrations)
        .and_return([pending_migration, obsolete_migration])

      expect { subject }.to output(
        /Pending Migrations\s+#{pending_migration.name}\s+#{obsolete_migration.name} \[Obsolete\]/
      ).to_stdout
    end

    it 'outputs current migration' do
      migration = ::Elastic::DataMigrationService.migrations.last
      allow(migration).to receive(:started?).and_return(true)
      allow(migration).to receive(:load_state).and_return({ test: 'value' })
      allow(Elastic::MigrationRecord).to receive(:current_migration).and_return(migration)

      expected_regex = Regexp.new([
        "Name:\\s+#{migration.name}\\s+",
        'Started:\\s+yes\\s+',
        'Halted:\\s+no\\s+',
        'Failed:\\s+no\\s+',
        'Obsolete:\\s+no\\s+',
        'Current state:\\s+{"test":"value"}'
      ].join(''))

      expect { subject }.to output(expected_regex).to_stdout
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

        expect { subject }.to output(
          /failed to load indices for gitlab-development/
        ).to_stdout
      end

      it 'outputs index settings' do
        indices = instance_double(Elasticsearch::API::Indices::IndicesClient)
        allow(es_helper.client).to receive(:indices).and_return(indices)
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

        expected = "#{setting.alias_name}:\n  " \
                   "number_of_shards: 5\n  " \
                   "number_of_replicas: 1\n  " \
                   "refresh_interval: 2s\n  " \
                   "blocks.write: yes"

        expect { subject }.to output(a_string_including(expected)).to_stdout
      end
    end
  end

  describe 'clear_index_status' do
    subject { run_rake_task('gitlab:elastic:clear_index_status') }

    it 'deletes all records for Elastic::GroupIndexStatus and IndexStatus tables' do
      expect(Elastic::GroupIndexStatus).to receive(:delete_all)
      expect(IndexStatus).to receive(:delete_all)

      expected = <<~STD_OUT
        Index status has been reset
      STD_OUT

      expect { subject }.to output(expected).to_stdout
    end
  end
end
