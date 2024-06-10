# frozen_string_literal: true

module Search
  module Elastic
    class TriggerIndexingWorker
      include ApplicationWorker
      prepend ::Geo::SkipSecondary

      INITIAL_TASK = :initiate
      TASKS = %i[namespaces projects snippets users].freeze

      data_consistency :delayed

      feature_category :global_search
      worker_resource_boundary :cpu
      idempotent!
      urgency :throttled

      def perform(task = INITIAL_TASK, options = {})
        return false if ::Gitlab::Saas.feature_available?(:advanced_search)

        task = task&.to_sym
        raise ArgumentError, "Unknown task: #{task}" unless allowed_tasks.include?(task)

        @options = options.with_indifferent_access

        case task
        when :initiate
          initiate
        when :namespaces
          task_executor_service.execute(:index_namespaces)
        when :projects
          task_executor_service.execute(:index_projects)
        when :snippets
          task_executor_service.execute(:index_snippets)
        when :users
          task_executor_service.execute(:index_users)
        end
      end

      private

      attr_reader :options

      def allowed_tasks
        [INITIAL_TASK] + TASKS
      end

      def initiate
        unless Gitlab::CurrentSettings.elasticsearch_indexing?
          ApplicationSettings::UpdateService.new(
            Gitlab::CurrentSettings.current_application_settings,
            nil,
            { elasticsearch_indexing: true }
          ).execute

          logger.info('Setting `elasticsearch_indexing` has been enabled.')
          self.class.perform_in(2.minutes, INITIAL_TASK, options)

          return false
        end

        unless ::Gitlab::CurrentSettings.elasticsearch_pause_indexing?
          task_executor_service.execute(:pause_indexing)

          self.class.perform_in(2.minutes, INITIAL_TASK, options)

          return false
        end

        task_executor_service.execute(:recreate_index)
        task_executor_service.execute(:clear_index_status)
        task_executor_service.execute(:resume_indexing)

        skip_tasks = Array.wrap(options[:skip]).map(&:to_sym)
        tasks_to_schedule = TASKS - skip_tasks

        tasks_to_schedule.each do |task|
          self.class.perform_async(task, options)
        end
      end

      def task_executor_service
        @task_executor_service ||= Search::RakeTaskExecutorService.new(logger: logger)
      end

      def logger
        @logger ||= ::Gitlab::Elasticsearch::Logger.build
      end
    end
  end
end
