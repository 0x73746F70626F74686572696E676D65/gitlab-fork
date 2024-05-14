# frozen_string_literal: true

module Search
  module Zoekt
    class Task < ApplicationRecord
      PARTITION_DURATION = 1.day
      PROCESSING_BATCH_SIZE = 100

      include PartitionedTable
      include IgnorableColumns
      include EachBatch

      self.table_name = 'zoekt_tasks'
      self.primary_key = :id

      ignore_column :partition_id, remove_never: true

      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :tasks, class_name: '::Search::Zoekt::Node'
      belongs_to :zoekt_repository, inverse_of: :tasks, class_name: '::Search::Zoekt::Repository'

      before_validation :set_project_identifier

      scope :for_partition, ->(partition) { where(partition_id: partition) }
      scope :with_project, -> { includes(zoekt_repository: :project) }
      scope :for_processing, -> { where(perform_at: (..Time.zone.now)) }

      enum state: {
        pending: 0,
        done: 10,
        failed: 255,
        orphaned: 256
      }

      enum task_type: {
        index_repo: 0,
        force_index_repo: 1,
        delete_repo: 50
      }

      partitioned_by :partition_id,
        strategy: :sliding_list,
        next_partition_if: ->(active_partition) do
          oldest_record_in_partition = Task
            .select(:id, :created_at)
            .for_partition(active_partition.value)
            .order(:id)
            .first

          oldest_record_in_partition.present? &&
            oldest_record_in_partition.created_at < PARTITION_DURATION.ago
        end,
        detach_partition_if: ->(partition) do
          !Task
            .for_partition(partition.value)
            .where(state: :pending)
            .exists?
        end

      def self.each_task(limit:)
        return unless block_given?

        count = 0

        scope = for_processing.pending.with_project.order(:perform_at, :id)
        iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: scope)

        iterator.each_batch(of: PROCESSING_BATCH_SIZE) do |tasks|
          orphaned_task_ids = []

          tasks.each do |task|
            unless task.delete_repo? || task.zoekt_repository&.project
              orphaned_task_ids << task.id
              next
            end

            yield task
            count += 1
            break if count >= limit
          end

          tasks.where(id: orphaned_task_ids).update_all(state: :orphaned) if orphaned_task_ids.any?

          break if count >= limit
        end
      end

      private

      def set_project_identifier
        self.project_identifier ||= zoekt_repository&.project_identifier
      end
    end
  end
end
