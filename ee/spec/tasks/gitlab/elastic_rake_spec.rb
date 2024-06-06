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

  context 'when rake executor tasks' do
    Search::RakeTaskExecutorService::TASKS.each do |task|
      describe "gitlab:elastic:#{task}" do
        include_examples 'rake task executor task', task
      end
    end
  end

  context 'with elasticsearch_indexing enabled' do
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

      describe 'gitlab:elastic:index_group_entities' do
        subject(:task) { run_rake_task('gitlab:elastic:index_group_entities') }

        context 'when on GitLab.com', :saas do
          it 'raises an error' do
            expect { task }.to raise_error('This task cannot be run on GitLab.com')
          end
        end

        it 'calls the index_group_entities in the rake task executor' do
          expect_next_instance_of(Search::RakeTaskExecutorService) do |instance|
            expect(instance).to receive(:execute).with(:index_group_entities)
          end

          task
        end
      end

      describe 'gitlab:elastic:index_group_wikis' do
        it 'calls the index_group_wikis in the rake task executor' do
          expect_next_instance_of(Search::RakeTaskExecutorService) do |instance|
            expect(instance).to receive(:execute).with(:index_group_wikis)
          end

          run_rake_task('gitlab:elastic:index_group_wikis')
        end
      end

      describe 'gitlab:elastic:recreate_index' do
        it 'calls the recreate_index in the rake task executor' do
          expect_next_instance_of(Search::RakeTaskExecutorService) do |instance|
            expect(instance).to receive(:execute).with(:recreate_index)
          end

          run_rake_task 'gitlab:elastic:recreate_index'
        end
      end
    end
  end

  context 'with elasticsearch_indexing is disabled' do
    describe 'gitlab:elastic:index' do
      it 'enables `elasticsearch_indexing`' do
        expect { run_rake_task 'gitlab:elastic:index' }.to change {
          Gitlab::CurrentSettings.elasticsearch_indexing?
        }.from(false).to(true)
      end
    end
  end
end
