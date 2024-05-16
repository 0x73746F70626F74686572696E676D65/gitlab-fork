# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        # Usage example
        #
        # In metric YAML definition:
        #
        # instrumentation_class: TotalCountMetric
        # options:
        #   event: commit_pushed
        #
        class TotalCountMetric < BaseMetric
          include Gitlab::UsageDataCounters::RedisCounter
          extend Gitlab::Usage::TimeSeriesStorable

          KEY_PREFIX = "{event_counters}_"

          def self.redis_key(event_name, date = nil, _used_in_aggregate_metric = false)
            base_key = KEY_PREFIX + event_name
            return base_key unless date

            apply_time_aggregation(base_key, date)
          end

          def value
            event_specific_part_of_paths = events.map do |event_selection_rule|
              Gitlab::InternalEvents.convert_event_selection_rule_to_path_part(event_selection_rule)
            end

            keys = if time_frame == 'all'
                     event_specific_part_of_paths.map do |event_specific_part_of_path|
                       self.class.redis_key(event_specific_part_of_path)
                     end
                   else
                     self.class.keys_for_aggregation(events: event_specific_part_of_paths, **time_constraint)
                   end

            keys.sum do |key|
              redis_usage_data do
                total_count(key)
              end
            end
          end

          def time_constraint
            case time_frame
            when '28d'
              monthly_time_range
            when '7d'
              weekly_time_range
            else
              raise "Unknown time frame: #{time_frame} for #{self.class} :: #{events}"
            end
          end

          def event_names
            events.pluck(:name)
          end
        end
      end
    end
  end
end
