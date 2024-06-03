# frozen_string_literal: true

module Search
  class ElasticIndexEmbeddingBulkCronWorker # rubocop:disable Scalability/IdempotentWorker -- worker has deduplication
    include ::Elastic::BulkCronWorker
    include Search::Elastic::Concerns::RateLimiter

    feature_category :global_search
    urgency :low
    data_consistency :sticky

    def perform(shard_number = nil)
      return if embeddings_throttled?

      super
    end

    private

    def service
      Search::Elastic::ProcessEmbeddingBookkeepingService.new
    end

    def re_enqueue_enabled?
      Feature.enabled?(:embedding_cron_worker_re_enqueue) # rubocop: disable Gitlab/FeatureFlagWithoutActor -- cron worker without actor
    end
  end
end
