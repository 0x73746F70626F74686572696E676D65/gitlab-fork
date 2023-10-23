# frozen_string_literal: true
module MergeRequests
  module Mergeability
    class RunChecksService
      include Gitlab::Utils::StrongMemoize

      def initialize(merge_request:, params:)
        @merge_request = merge_request
        @params = params
      end

      def execute(checks, execute_all: false)
        @results = checks.each_with_object([]) do |check_class, result_hash|
          check = check_class.new(merge_request: merge_request, params: params)

          next if check.skip?

          check_result = logger.instrument(mergeability_name: check_class.to_s.demodulize.underscore) do
            run_check(check)
          end

          result_hash << check_result

          break result_hash if check_result.failed? && !execute_all
        end

        logger.commit

        return ServiceResponse.success(payload: { results: results }) if all_results_success?

        ServiceResponse.error(
          message: 'Checks failed.',
          payload: {
            results: results,
            failure_reason: failure_reason
          }
        )
      end

      private

      attr_reader :merge_request, :params, :results

      def run_check(check)
        return check.execute unless check.cacheable?

        cached_result = cached_results.read(merge_check: check)
        return cached_result if cached_result.respond_to?(:status)

        check.execute.tap do |result|
          cached_results.write(merge_check: check, result_hash: result.to_hash)
        end
      end

      def cached_results
        strong_memoize(:cached_results) do
          Gitlab::MergeRequests::Mergeability::ResultsStore.new(merge_request: merge_request)
        end
      end

      def logger
        strong_memoize(:logger) do
          MergeRequests::Mergeability::Logger.new(merge_request: merge_request)
        end
      end

      def all_results_success?
        results.none?(&:failed?)
      end

      def failure_reason
        results.find(&:failed?)&.payload&.fetch(:reason)&.to_sym
      end
    end
  end
end
