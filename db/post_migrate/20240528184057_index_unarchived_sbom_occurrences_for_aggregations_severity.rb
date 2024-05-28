# frozen_string_literal: true

class IndexUnarchivedSbomOccurrencesForAggregationsSeverity < Gitlab::Database::Migration[2.2]
  INDEX_NAME = 'index_unarchived_occurrences_for_aggregations_severity'

  milestone '17.1'

  disable_ddl_transaction!

  def up
    add_concurrent_index :sbom_occurrences, [:highest_severity, :component_version_id, :traversal_ids],
      where: 'archived = false',
      name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :sbom_occurrences, INDEX_NAME
  end
end
