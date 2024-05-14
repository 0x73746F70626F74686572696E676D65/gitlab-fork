# frozen_string_literal: true

module Zoekt
  class IndexerWorker
    MAX_JOBS_PER_HOUR = 3600
    TIMEOUT = 2.hours
    RETRY_IN_IF_LOCKED = 10.minutes
    RETRY_IN_PERIOD_IF_TOO_MANY_REQUESTS = 5.minutes

    REINDEXING_CHANCE_PERCENTAGE = 0.5

    include ApplicationWorker
    prepend ::Geo::SkipSecondary

    data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency -- This worker updates data
    include Gitlab::ExclusiveLeaseHelpers

    feature_category :global_search
    urgency :throttled
    sidekiq_options retry: 2
    idempotent!
    pause_control :zoekt
    concurrency_limit -> { 30 if Feature.enabled?(:zoekt_limit_indexing_concurrency) }

    def perform(project_id, options = {})
      return unless ::Feature.enabled?(:index_code_with_zoekt)
      return unless ::License.feature_available?(:zoekt_code_search)

      project = Project.find_by_id(project_id)
      return false unless project
      return true unless project.use_zoekt?
      return true unless project.repository_exists?
      return true if project.empty_repo?

      in_lock("#{self.class.name}/#{project_id}", ttl: (TIMEOUT + 1.minute), retries: 0) do
        force = !!options['force'] || random_force_reindexing?(project)

        project.repository.update_zoekt_index!(force: force)
      end
    rescue Gitlab::Search::Zoekt::Client::TooManyRequestsError
      delay = rand(RETRY_IN_PERIOD_IF_TOO_MANY_REQUESTS)
      self.class.perform_in(delay, project_id, options)
    rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
      self.class.perform_in(RETRY_IN_IF_LOCKED, project_id, options)
    end

    private

    # This is needed as a temporary band-aid solution for https://gitlab.com/gitlab-org/gitlab/-/issues/435765
    def random_force_reindexing?(project)
      return false if Feature.disabled?(:zoekt_random_force_reindexing, project, type: :ops)

      rand * 100 <= REINDEXING_CHANCE_PERCENTAGE
    end
  end
end
