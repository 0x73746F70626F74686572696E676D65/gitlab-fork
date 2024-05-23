# frozen_string_literal: true

module ClickHouse
  class CodeSuggestionEventsCronWorker
    include ApplicationWorker
    include ClickHouseWorker

    idempotent!
    queue_namespace :cronjob
    data_consistency :delayed
    worker_has_external_dependencies! # the worker interacts with a ClickHouse database
    feature_category :value_stream_management

    MAX_RUNTIME = 200.seconds
    BATCH_SIZE = 1000

    CSV_MAPPING = {
      user_id: :user_id,
      timestamp: :timestamp,
      event: :event
    }.freeze

    INSERT_QUERY = <<~SQL.squish
      INSERT INTO code_suggestion_usages (#{CSV_MAPPING.keys.join(', ')})
      SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV
    SQL

    def perform
      return unless enabled?

      connection.ping # ensure CH is available

      status, inserted_rows = loop_with_runtime_limit(MAX_RUNTIME) do
        insert_rows(build_rows)
      end

      log_extra_metadata_on_done(:result, {
        status: status,
        inserted_rows: inserted_rows
      })
    end

    private

    def loop_with_runtime_limit(limit)
      status = :processed
      total_inserted_rows = 0

      runtime_limiter = Gitlab::Metrics::RuntimeLimiter.new(limit)

      loop do
        if runtime_limiter.over_time?
          status = :over_time
          break
        end

        inserted_rows = yield
        total_inserted_rows += inserted_rows

        break if inserted_rows == 0
      end

      [status, total_inserted_rows]
    end

    def enabled?
      Gitlab::ClickHouse.globally_enabled_for_analytics? &&
        Feature.enabled?(:code_suggestion_events_in_click_house)
    end

    def build_rows
      # Using LPOP which is not crash-safe. There is a small chance for data loss
      # if ClickHouse is down or the worker crashes before the INSERT.
      ClickHouse::WriteBuffer.pop_events(BATCH_SIZE).filter_map do |hash|
        build_row(hash)
      end
    end

    def build_row(hash)
      return unless CSV_MAPPING.keys.all? { |key| hash[key] }

      # Legacy data format. Remove with next deploy.
      hash[:timestamp] = hash[:timestamp].is_a?(String) ? DateTime.parse(hash[:timestamp]).to_f : hash[:timestamp]
      hash
    end

    def insert_rows(rows)
      CsvBuilder::Gzip.new(rows, CSV_MAPPING).render do |tempfile, rows_written|
        if rows_written == 0
          0
        else
          connection.insert_csv(INSERT_QUERY, File.open(tempfile.path))
          rows.size
        end
      end
    end

    def connection
      @connection ||= ClickHouse::Connection.new(:main)
    end
  end
end
