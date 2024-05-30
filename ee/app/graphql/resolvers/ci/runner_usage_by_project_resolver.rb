# frozen_string_literal: true

module Resolvers
  module Ci
    class RunnerUsageByProjectResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      MAX_PROJECTS_LIMIT = 500
      DEFAULT_PROJECTS_LIMIT = 5

      authorize :read_runner_usage

      type [Types::Ci::RunnerUsageByProjectType], null: true
      description <<~MD
        Runner usage in minutes by project. Available only to admins.
      MD

      argument :runner_type, ::Types::Ci::RunnerTypeEnum,
        required: false,
        description: 'Filter jobs by the type of runner that executed them.'

      argument :from_date, Types::DateType,
        required: false,
        description: 'Start of the requested date frame. Defaults to the start of the previous calendar month.'

      argument :to_date, Types::DateType,
        required: false,
        description: 'End of the requested date frame. Defaults to the end of the previous calendar month.'

      argument :projects_limit, GraphQL::Types::Int,
        required: false,
        description: 'Maximum number of projects to return.' \
                     'Other projects will be aggregated to a `project: null` entry. ' \
                     "Defaults to #{DEFAULT_PROJECTS_LIMIT} if unspecified. Maximum of #{MAX_PROJECTS_LIMIT}."

      def resolve(from_date: nil, to_date: nil, runner_type: nil, projects_limit: nil)
        authorize! :global

        from_date ||= 1.month.ago.beginning_of_month.to_date
        to_date ||= 1.month.ago.end_of_month.to_date

        if (to_date - from_date).days > 1.year || from_date > to_date
          raise Gitlab::Graphql::Errors::ArgumentError,
            "'to_date' must be greater than 'from_date' and be within 1 year"
        end

        result = ::Ci::Runners::GetUsageByProjectService.new(
          current_user,
          runner_type: runner_type,
          from_date: from_date,
          to_date: to_date,
          max_item_count: [MAX_PROJECTS_LIMIT, projects_limit || DEFAULT_PROJECTS_LIMIT].min
        ).execute

        raise Gitlab::Graphql::Errors::ArgumentError, result.message if result.error?

        prepare_result(result.payload)
      end

      private

      def prepare_result(payload)
        payload.map do |project_usage|
          {
            project_id: project_usage['project_id_bucket'],
            ci_minutes_used: project_usage['total_duration_in_mins'],
            ci_build_count: project_usage['count_builds']
          }
        end
      end
    end
  end
end
