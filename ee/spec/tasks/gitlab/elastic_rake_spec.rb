# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:elastic namespace rake tasks', :silence_stdout, feature_category: :global_search do
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

  describe 'gitlab:elastic:index_group_entities' do
    include_examples 'rake task executor task', :index_group_entities
  end

  describe 'gitlab:elastic:enable_search_with_elasticsearch' do
    include_examples 'rake task executor task', :enable_search_with_elasticsearch
  end

  describe 'gitlab:elastic:disable_search_with_elasticsearch' do
    include_examples 'rake task executor task', :disable_search_with_elasticsearch
  end

  describe 'gitlab:elastic:index_projects' do
    include_examples 'rake task executor task', :index_projects
  end

  describe 'gitlab:elastic:index_projects_status' do
    include_examples 'rake task executor task', :index_projects_status
  end

  describe 'gitlab:elastic:index_snippets' do
    include_examples 'rake task executor task', :index_snippets
  end

  describe 'gitlab:elastic:index_users' do
    include_examples 'rake task executor task', :index_users
  end

  describe 'gitlab:elastic:index_epics' do
    include_examples 'rake task executor task', :index_epics
  end

  describe 'gitlab:elastic:index_group_wikis' do
    include_examples 'rake task executor task', :index_group_wikis
  end

  describe 'gitlab:elastic:create_empty_index' do
    include_examples 'rake task executor task', :create_empty_index
  end

  describe 'gitlab:elastic:delete_index' do
    include_examples 'rake task executor task', :delete_index
  end

  describe 'gitlab:elastic:recreate_index' do
    include_examples 'rake task executor task', :recreate_index
  end

  describe 'gitlab:elastic:reindex_cluster' do
    include_examples 'rake task executor task', :reindex_cluster
  end

  describe 'gitlab:elastic:clear_index_status' do
    include_examples 'rake task executor task', :clear_index_status
  end

  describe 'gitlab:elastic:projects_not_indexed' do
    include_examples 'rake task executor task', :projects_not_indexed
  end

  describe 'gitlab:elastic:mark_reindex_failed' do
    include_examples 'rake task executor task', :mark_reindex_failed
  end

  describe 'gitlab:elastic:list_pending_migrations' do
    include_examples 'rake task executor task', :list_pending_migrations
  end

  describe 'gitlab:elastic:estimate_cluster_size' do
    include_examples 'rake task executor task', :estimate_cluster_size
  end

  describe 'gitlab:elastic:estimate_shard_sizes' do
    include_examples 'rake task executor task', :estimate_shard_sizes
  end

  describe 'gitlab:elastic:pause_indexing' do
    include_examples 'rake task executor task', :pause_indexing
  end

  describe 'gitlab:elastic:resume_indexing' do
    include_examples 'rake task executor task', :resume_indexing
  end

  describe 'gitlab:elastic:info' do
    include_examples 'rake task executor task', :info
  end

  describe 'gitlab:elastic:index' do
    let(:logger) { Logger.new(StringIO.new) }

    subject(:task) { run_rake_task('gitlab:elastic:index') }

    before do
      allow(main_object).to receive(:stdout_logger).and_return(logger)
      allow(logger).to receive(:info)
    end

    context 'with elasticsearch_indexing is disabled' do
      context 'when elastic_index_use_trigger_indexing is enabled' do
        before do
          stub_feature_flags(elastic_index_use_trigger_indexing: true)
        end

        it 'does not enable `elasticsearch_indexing`' do
          expect { run_rake_task 'gitlab:elastic:index' }.not_to change {
            Gitlab::CurrentSettings.elasticsearch_indexing?
          }
        end
      end

      context 'when elastic_index_use_trigger_indexing is disabled' do
        before do
          stub_feature_flags(elastic_index_use_trigger_indexing: false)
        end

        it 'enables `elasticsearch_indexing`' do
          expect { run_rake_task 'gitlab:elastic:index' }.to change {
            Gitlab::CurrentSettings.elasticsearch_indexing?
          }.from(false).to(true)
        end
      end
    end

    context 'with elasticsearch_indexing enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { task }.to raise_error('This task cannot be run on GitLab.com')
        end
      end

      it 'schedules Search::Elastic::TriggerIndexingWorker asynchronously' do
        expect(::Search::Elastic::TriggerIndexingWorker).to receive(:perform_in)
          .with(1.minute, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK, { 'skip' => 'projects' })

        task
      end

      it 'outputs warning if indexing is paused' do
        stub_ee_application_setting(elasticsearch_pause_indexing: true)

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

        it 'outputs warning if indexing is paused and still runs all indexing tasks in order' do
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
  end
end
