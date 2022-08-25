# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class Logger
      include Gitlab::Utils::StrongMemoize

      def initialize(merge_request:, destination: Gitlab::AppJsonLogger)
        @destination = destination
        @merge_request = merge_request
      end

      def commit
        return unless enabled?

        commit_logs
      end

      def instrument(mergeability_name:)
        raise ArgumentError, 'block not given' unless block_given?

        return yield unless enabled?

        op_start_db_counters = current_db_counter_payload
        op_started_at = current_monotonic_time

        result = yield

        observe("mergeability.#{mergeability_name}.duration_s", current_monotonic_time - op_started_at)

        observe_sql_counters(mergeability_name, op_start_db_counters, current_db_counter_payload)

        result
      end

      private

      attr_reader :destination, :merge_request

      def observe(name, value)
        return unless enabled?

        observations[name.to_s].push(value)
      end

      def commit_logs
        attributes = Gitlab::ApplicationContext.current.merge({
                                                                mergeability_project_id: merge_request.project.id
                                                              })

        attributes[:mergeability_merge_request_id] = merge_request.id
        attributes.merge!(observations_hash)
        attributes.compact!
        attributes.stringify_keys!

        destination.info(attributes)
      end

      def observations_hash
        transformed = observations.transform_values do |values|
          next if values.empty?

          {
            'values' => values
          }
        end.compact

        transformed.each_with_object({}) do |key, hash|
          key[1].each { |k, v| hash["#{key[0]}.#{k}"] = v }
        end
      end

      def observations
        strong_memoize(:observations) do
          Hash.new { |hash, key| hash[key] = [] }
        end
      end

      def observe_sql_counters(name, start_db_counters, end_db_counters)
        end_db_counters.each do |key, value|
          result = value - start_db_counters.fetch(key, 0)
          next if result == 0

          observe("mergeability.#{name}.#{key}", result)
        end
      end

      def current_db_counter_payload
        ::Gitlab::Metrics::Subscribers::ActiveRecord.db_counter_payload
      end

      def enabled?
        strong_memoize(:enabled) do
          ::Feature.enabled?(:mergeability_checks_logger, merge_request.project)
        end
      end

      def current_monotonic_time
        ::Gitlab::Metrics::System.monotonic_time
      end
    end
  end
end
