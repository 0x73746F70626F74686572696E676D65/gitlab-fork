# frozen_string_literal: true

module Ci
  class FinishedBuildChSyncEvent < Ci::ApplicationRecord
    include EachBatch
    include PartitionedTable
    include IgnorableColumns

    PARTITION_DURATION = 1.day
    PARTITION_CLEANUP_THRESHOLD = 1.year

    self.table_name = :p_ci_finished_build_ch_sync_events
    self.primary_key = :build_id

    ignore_columns :partition, remove_never: true

    partitioned_by :partition, strategy: :sliding_list,
      next_partition_if: ->(active_partition) do
        next_partition_if(active_partition)
      end,
      detach_partition_if: ->(partition) do
        detach_partition?(partition)
      end

    validates :build_id, presence: true
    validates :build_finished_at, presence: true

    scope :order_by_build_id, -> { order(:build_id) }

    scope :pending, -> { where(processed: false) }
    scope :for_partition, ->(partition) { where(partition: partition) }

    def self.next_partition_if(active_partition)
      oldest_record_in_partition = FinishedBuildChSyncEvent.for_partition(active_partition.value)
        .order(:build_finished_at).first

      oldest_record_in_partition.present? &&
        oldest_record_in_partition.build_finished_at < PARTITION_DURATION.ago
    end

    def self.detach_partition?(partition)
      # if there are no pending events
      return true unless FinishedBuildChSyncEvent.pending.for_partition(partition.value).exists?

      # if partition only has the very old data
      newest_record_in_partition = FinishedBuildChSyncEvent.for_partition(partition.value)
        .order(:build_finished_at).last

      newest_record_in_partition.present? &&
        newest_record_in_partition.build_finished_at < PARTITION_CLEANUP_THRESHOLD.ago
    end
  end
end
