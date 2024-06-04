# frozen_string_literal: true

module Ci
  module Partitions
    class SetupDefaultService
      DEFAULT_PARTITION_IDS = [
        Ci::Pipeline::INITIAL_PARTITION_VALUE,
        Ci::Pipeline::SECOND_PARTITION_VALUE,
        Ci::Pipeline::NEXT_PARTITION_VALUE
      ].freeze

      def execute
        return unless Feature.enabled?(:ci_partitioning_first_records, :instance)
        return if Ci::Partition.current

        setup_default_partitions
      end

      private

      def setup_default_partitions
        setup_active_partitions
        setup_current_partition
      end

      def setup_active_partitions
        active_partitions = DEFAULT_PARTITION_IDS
          .map { |value| { id: value, status: Ci::Partition.statuses[:active] } }

        Ci::Partition.upsert_all(active_partitions, unique_by: :id)
      end

      def setup_current_partition
        Ci::Partition.find(Ci::Pipeline.current_partition_value).update!(status: Ci::Partition.statuses[:current])
      end
    end
  end
end
