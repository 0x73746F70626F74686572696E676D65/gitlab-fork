# frozen_string_literal: true

module Resolvers
  module Ci
    class RunnerUsageResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      MAX_RUNNERS_LIMIT = 500
      DEFAULT_RUNNERS_LIMIT = 5

      authorize :read_runner_usage

      type [Types::Ci::RunnerUsageType], null: true
      description <<~MD
        Runner usage. Available only to admins.
      MD

      argument :runner_type, ::Types::Ci::RunnerTypeEnum,
        required: false,
        description: 'Filter runners by the type.'

      argument :from_date, Types::DateType,
        required: false,
        description: 'Start of the requested date frame. Defaults to the start of the previous calendar month.'

      argument :to_date, Types::DateType,
        required: false,
        description: 'End of the requested date frame. Defaults to the end of the previous calendar month.'

      argument :runners_limit, GraphQL::Types::Int,
        required: false,
        default_value: DEFAULT_RUNNERS_LIMIT,
        description: 'Maximum number of runners to return. ' \
                     'Other runners will be aggregated to a `runner: null` entry. ' \
                     "Defaults to #{DEFAULT_RUNNERS_LIMIT} if unspecified. Maximum of #{MAX_RUNNERS_LIMIT}."

      def resolve(from_date: nil, to_date: nil, runner_type: nil, runners_limit: nil)
        authorize! :global

        from_date ||= 1.month.ago.beginning_of_month.to_date
        to_date ||= 1.month.ago.end_of_month.to_date

        if (to_date - from_date).days > 1.year || from_date > to_date
          raise Gitlab::Graphql::Errors::ArgumentError,
            "'to_date' must be greater than 'from_date' and be within 1 year"
        end

        result = ::Ci::Runners::GetUsageService.new(current_user,
          runner_type: runner_type,
          from_date: from_date,
          to_date: to_date,
          max_runners_count: [MAX_RUNNERS_LIMIT, runners_limit || DEFAULT_RUNNERS_LIMIT].min
        ).execute

        raise_resource_not_available_error!(result.message) if result.error?

        prepare_result(result.payload)
      end

      private

      def prepare_result(payload)
        payload.map do |runner_usage|
          {
            runner_id: runner_usage['runner_id'],
            ci_minutes_used: runner_usage['total_duration_in_mins'],
            ci_build_count: runner_usage['count_builds']
          }
        end
      end
    end
  end
end
