# frozen_string_literal: true

module Resolvers
  module Analytics
    module ValueStreamDashboard
      class CountResolver < BaseResolver
        type ::Types::Analytics::ValueStreamDashboard::CountType, null: true

        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorizes_object!
        authorize :read_group_analytics_dashboards

        argument :identifier, Types::Analytics::ValueStreamDashboard::MetricEnum,
          required: true,
          description: 'Type of counts to retrieve.'

        argument :timeframe, Types::TimeframeInputType,
          required: true,
          description: 'Counts recorded during this time frame, usually from beginning of ' \
                       'the month until the end of the month (the system runs monthly aggregations).'

        def resolve(identifier:, timeframe:)
          count, last_recorded_at = if queries_contributors?(identifier)
                                      contributor_count_data(timeframe)
                                    else
                                      ::Analytics::ValueStreamDashboard::Count
                                        .aggregate_for_period(
                                          group,
                                          identifier.to_sym,
                                          timeframe[:start],
                                          timeframe[:end]
                                        )
                                    end

          return unless last_recorded_at

          {
            recorded_at: last_recorded_at,
            count: count,
            identifier: identifier
          }
        end

        private

        alias_method :group, :object

        def queries_contributors?(identifier)
          identifier == Types::Analytics::ValueStreamDashboard::MetricEnum::CONTRIBUTOR_METRIC
        end

        def contributor_count_data(timeframe)
          service_response = ::Analytics::ValueStreamDashboard::ContributorCountService
            .new(
              group: group,
              current_user: current_user,
              from: timeframe[:start],
              to: timeframe[:end]
            ).execute

          if service_response.error?
            raise GraphQL::ExecutionError,
              service_response.message
          end

          # Since this is not an aggregated metric, we can return the current time for the last_record_at_value.
          [service_response.payload[:count], Time.current]
        end
      end
    end
  end
end
