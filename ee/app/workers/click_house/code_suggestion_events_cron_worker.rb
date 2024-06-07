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

    INSERT_QUERY_TEMPLATE = <<~SQL.squish
      INSERT INTO %{table_name} (%{fields}) SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV
    SQL

    def perform
      return unless enabled?

      connection.ping # ensure CH is available

      status, inserted_rows = loop_with_runtime_limit(MAX_RUNTIME) do
        process_next_batch
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
      Gitlab::ClickHouse.globally_enabled_for_analytics?
    end

    def process_next_batch
      next_batch.group_by(&:keys).sum do |keys, rows|
        insert_rows(rows, mapping: build_csv_mapping(keys))
      end
    end

    def next_batch
      ClickHouse::WriteBuffer.pop(Ai::CodeSuggestionsUsage.table_name, BATCH_SIZE)
    end

    def build_csv_mapping(keys)
      keys.to_h { |key| [key.to_sym, key.to_sym] }
    end

    def insert_rows(rows, mapping:)
      CsvBuilder::Gzip.new(rows, mapping).render do |tempfile, rows_written|
        if rows_written == 0
          0
        else
          connection.insert_csv(prepare_insert_statement(mapping), File.open(tempfile.path))
          rows.size
        end
      end
    end

    def prepare_insert_statement(mapping)
      format(INSERT_QUERY_TEMPLATE, fields: mapping.keys.join(', '), table_name: Ai::CodeSuggestionsUsage.table_name)
    end

    def connection
      @connection ||= ClickHouse::Connection.new(:main)
    end
  end
end
