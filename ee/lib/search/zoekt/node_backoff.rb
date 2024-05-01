# frozen_string_literal: true

module Search
  module Zoekt
    class NodeBackoff
      DEFAULT_MAXIMUM_BACKOFF = 30.minutes

      attr_reader :node, :max_backoff, :num_failures, :expires_at

      def initialize(node, max_backoff: DEFAULT_MAXIMUM_BACKOFF)
        @node = node

        raise ArgumentError, "Maximum backoff must be greater than or equal to a minute" if max_backoff < 1.minute

        @max_backoff = max_backoff
        reload!
      end

      def seconds_remaining
        return 0 unless expires_at.present?

        (expires_at - Time.zone.now).clamp(0..)
      end

      def reload!
        @num_failures = cached_num_failures
        set_expiry

        self
      end

      def backoff!
        increment_num_failures
        set_expiry

        cache_store.with do |redis|
          redis.multi do |m|
            m.incr(backoff_cache_key)
            m.expireat(backoff_cache_key, expires_at.to_i)
          end
        end

        logger.info(
          message: 'Node back off enabled',
          class: self.class.name,
          zoekt_node: {
            id: node.id,
            uuid: node.uuid,
            backoff: {
              num_failures: num_failures,
              expires_at: expires_at
            }
          }
        )

        num_failures
      end

      def remove_backoff!
        cache_store.with do |redis|
          redis.del(backoff_cache_key)
        end

        @num_failures = 0
      end

      def enabled?
        reload!
        num_failures > 0
      end

      def backoff_cache_key
        [self.class.name, node.id].join('-')
      end

      def expires_in_s
        backoff_time_s = calculate_backoff_time_s
        backoff_time_s >= max_backoff ? max_backoff : backoff_time_s
      end

      private

      def increment_num_failures
        reload!
        @num_failures += 1
      end

      def set_expiry
        @expires_at = expires_in_s.from_now
      end

      def cached_num_failures
        cache_store.with do |redis|
          redis.get(backoff_cache_key).to_i
        end
      end

      def calculate_backoff_time_s
        ((2**num_failures) + rand(0.001..1)).seconds
      end

      def cache_store
        ::Gitlab::Redis::SharedState
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
