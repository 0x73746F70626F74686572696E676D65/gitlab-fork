# frozen_string_literal: true

module Analytics
  module CycleAnalytics
    class DataLoaderService
      include Validations

      MAX_UPSERT_COUNT = 100_000
      UPSERT_LIMIT = 1000
      BATCH_LIMIT = 500
      EVENTS_LIMIT = 25

      CONFIG_MAPPING = {
        Issue => { event_model: IssueStageEvent }.freeze,
        MergeRequest => { event_model: MergeRequestStageEvent }.freeze
      }.freeze

      def initialize(group:, model:, context: Analytics::CycleAnalytics::AggregationContext.new)
        @group = group # could also be a Namespaces::UserNamespace object
        @model = model
        @context = context
        @upsert_count = 0

        load_stages # ensure stages are loaded/created
      end

      def execute
        error_response = validate
        return error_response if error_response

        response = success(:model_processed, context: context)

        context.processing_start!
        iterator.each_batch(of: BATCH_LIMIT) do |records|
          loaded_records = records.to_a

          break if records.empty?

          load_timestamp_data_into_value_stream_analytics(loaded_records)

          context.processed_records += loaded_records.size
          context.cursor = cursor_for_node(loaded_records.last)

          if upsert_count >= MAX_UPSERT_COUNT || context.over_time?
            response = success(:limit_reached, context: context)
            break
          end
        end

        context.processing_finished!

        response
      end

      private

      attr_reader :group, :model, :context, :upsert_count, :stages

      # rubocop: disable CodeReuse/ActiveRecord
      def iterator_base_scope
        model.order(:updated_at, :id)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def iterator
        opts = {
          in_operator_optimization_options: {
            array_scope: group.all_project_ids,
            array_mapping_scope: ->(id_expression) {
                                   model.where(model.arel_table[event_model.project_column].eq(id_expression))
                                 }
          }
        }

        Gitlab::Pagination::Keyset::Iterator.new(scope: iterator_base_scope, cursor: context.cursor, **opts)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def load_timestamp_data_into_value_stream_analytics(loaded_records)
        records_by_id = {}

        events.each_slice(EVENTS_LIMIT) do |event_slice|
          scope = model.join_project.id_in(loaded_records.pluck(:id))

          current_select_columns = event_model.select_columns # default SELECT columns
          # Add the stage timestamp columns to the SELECT
          event_slice.each do |event|
            scope = event.include_in(scope, include_all_timestamps_as_array: true)
            current_select_columns << event.timestamp_projection.as(event_column_name(event))
          end

          record_attributes = scope
            .reselect(*current_select_columns)
            .to_a
            .map(&:attributes)

          records_by_id.deep_merge!(record_attributes.index_by { |attr| attr['id'] }.compact)
        end

        upsert_data(records_by_id)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def upsert_data(records)
        data = []

        records.each_value do |record|
          stages.each do |stage|
            start_event_timestamp, end_event_timestamp, duration_in_milliseconds = calculate_duration(
              record[event_column_name(stage.start_event)],
              record[event_column_name(stage.end_event)]
            )

            next if start_event_timestamp.nil?

            data << {
              stage_event_hash_id: stage.stage_event_hash_id,
              issuable_id: record['id'],
              group_id: record['group_id'],
              project_id: record['project_id'],
              author_id: record['author_id'],
              milestone_id: record['milestone_id'],
              state_id: record['state_id'],
              start_event_timestamp: start_event_timestamp,
              end_event_timestamp: end_event_timestamp,
              duration_in_milliseconds: duration_in_milliseconds,
              weight: record['weight'],
              sprint_id: record['sprint_id']
            }

            if data.size == UPSERT_LIMIT
              @upsert_count += event_model.upsert_data(data)
              data.clear
            end
          end
        end

        @upsert_count += event_model.upsert_data(data) if data.any?
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def cursor_for_node(record)
        scope, _ = Gitlab::Pagination::Keyset::SimpleOrderBuilder.build(iterator_base_scope)
        order = Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(scope)
        order.cursor_attributes_for_node(record)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def event_model
        CONFIG_MAPPING.fetch(model).fetch(:event_model)
      end

      def event_column_name(event)
        "column_" + event.hash_code[0...10]
      end

      def load_stages
        @stages ||= ::Gitlab::Analytics::CycleAnalytics::DistinctStageLoader
          .new(group: group)
          .stages
          .select { |stage| stage.start_event.object_type == model }
      end

      def events
        @events ||= stages
          .flat_map { |stage| [stage.start_event, stage.end_event] }
          .uniq { |event| event.hash_code }
      end

      def calculate_duration(start_event_timestamp, end_event_timestamp)
        return if start_event_timestamp.nil?

        start_event_timestamps = Array.wrap(start_event_timestamp)
        # reverse is needed because the DB returns these in DESC order
        end_event_timestamps = Array.wrap(end_event_timestamp).reverse
        duration = 0

        return [start_event_timestamps.first, nil, nil] if end_event_timestamp.nil?

        # Handle the case when the timestamp arrays are uneven. Measure the duration
        # between the first start event timestamp and the last end event timestamp.
        if start_event_timestamps.size != end_event_timestamps.size
          start_event_timestamps = start_event_timestamps.first(1)
          end_event_timestamps = end_event_timestamps.last(1)
        end

        start_event_timestamps.zip(end_event_timestamps).each do |t1, t2|
          duration += (t2 - t1).in_milliseconds if t2 && t2 > t1
        end

        # Under normal circumstances 0ms duration is unlikely to happen. For example
        # adding and removing the label will never happen at the same time.
        return if duration == 0

        [
          start_event_timestamps.first,
          end_event_timestamps.last,
          duration
        ]
      end
    end
  end
end
