# frozen_string_literal: true

module Gitlab
  module Database
    class PostgresPartition < SharedModel
      self.primary_key = :identifier

      belongs_to :postgres_partitioned_table, foreign_key: 'parent_identifier', primary_key: 'identifier'

      # identifier includes the partition schema.
      # For example 'gitlab_partitions_static.events_03', or 'gitlab_partitions_dynamic.logs_03'
      scope :for_identifier, ->(identifier) do
        unless identifier =~ Gitlab::Database::FULLY_QUALIFIED_IDENTIFIER
          raise ArgumentError, "Partition name is not fully qualified with a schema: #{identifier}"
        end

        where(primary_key => identifier)
      end

      scope :by_identifier, ->(identifier) do
        for_identifier(identifier).first!
      end

      scope :for_parent_table, ->(parent_table) do
        if parent_table =~ Database::FULLY_QUALIFIED_IDENTIFIER
          where(parent_identifier: parent_table).order(:name)
        else
          where("parent_identifier = concat(current_schema(), '.', ?)", parent_table).order(:name)
        end
      end

      def self.partition_exists?(table_name)
        where("identifier = concat(current_schema(), '.', ?)", table_name).exists?
      end

      def self.legacy_partition_exists?(table_name)
        result = connection.select_value(<<~SQL)
          SELECT true FROM pg_class
          WHERE relname = '#{table_name}'
          AND relispartition = true;
        SQL

        !!result
      end

      def to_s
        name
      end
    end
  end
end
