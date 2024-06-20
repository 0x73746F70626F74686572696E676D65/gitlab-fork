# frozen_string_literal: true

class ElasticClusterReindexingCronWorker
  include ApplicationWorker

  data_consistency :always
  include CronjobQueue # rubocop:disable Scalability/CronWorkerContext
  include Gitlab::ExclusiveLeaseHelpers
  prepend ::Geo::SkipSecondary

  sidekiq_options retry: false

  feature_category :global_search
  urgency :throttled
  idempotent!

  def perform
    in_lock(self.class.name.underscore, ttl: 1.hour, retries: 10, sleep_sec: 1) do
      Elastic::ReindexingTask.drop_old_indices!

      task = Elastic::ReindexingTask.current
      break false unless task

      service.execute
    end
  end

  private

  def service
    ::Search::Elastic::ClusterReindexingService.new
  end
end
