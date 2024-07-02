# frozen_string_literal: true

module Resolvers
  module Analytics
    class AiMetricsResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource
      include LooksAhead

      type ::Types::Analytics::AiMetrics, null: true

      authorizes_object!
      authorize :read_ai_analytics

      argument :start_date, Types::DateType,
        required: false,
        description: 'Date range to start from. Default is the beginning of current month.'

      argument :end_date, Types::DateType,
        required: false,
        description: 'Date range to end at. Default is the end of current month.'

      def ready?(**args)
        validate_params!(args)

        super
      end

      def resolve_with_lookahead(**args)
        params = params_with_defaults(args)

        service_response = ::Analytics::AiAnalytics::CodeSuggestionUsageService.new(
          current_user,
          namespace: namespace,
          from: params[:start_date],
          to: params[:end_date],
          fields: selected_fields
        ).execute

        return unless service_response.success?

        service_response.payload
      end

      private

      def validate_params!(args)
        params = params_with_defaults(args)

        return unless params[:start_date] < params[:end_date] - 1.year

        raise Gitlab::Graphql::Errors::ArgumentError, 'maximum date range is 1 year'
      end

      def params_with_defaults(args)
        { start_date: Time.current.beginning_of_month, end_date: Time.current.end_of_month }.merge(args)
      end

      def namespace
        object.respond_to?(:project_namespace) ? object.project_namespace : object
      end

      def selected_fields
        ::Analytics::AiAnalytics::CodeSuggestionUsageService::FIELDS.select do |field|
          lookahead.selects?(field)
        end
      end
    end
  end
end
