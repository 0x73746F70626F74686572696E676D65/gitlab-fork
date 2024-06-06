# frozen_string_literal: true

module ClickHouse
  class DumpAllWriteBuffersCronWorker
    include ApplicationWorker

    idempotent!
    queue_namespace :cronjob
    data_consistency :delayed
    feature_category :database

    def perform
      return unless enabled?

      buffered_tables.each do |table_name|
        DumpWriteBufferWorker.perform_async(table_name)
      end
    end

    def buffered_tables
      @buffered_tables ||= ClickHouseModel.descendants.map(&:table_name)
    end

    private

    def enabled?
      Gitlab::ClickHouse.globally_enabled_for_analytics?
    end
  end
end
