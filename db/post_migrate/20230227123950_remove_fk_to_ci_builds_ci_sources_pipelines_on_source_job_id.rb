# frozen_string_literal: true

class RemoveFkToCiBuildsCiSourcesPipelinesOnSourceJobId < Gitlab::Database::Migration[2.1]
  disable_ddl_transaction!

  SOURCE_TABLE_NAME = :ci_sources_pipelines
  TARGET_TABLE_NAME = :ci_builds
  COLUMN = :source_job_id
  TARGET_COLUMN = :id
  FK_NAME = :fk_be5624bf37

  def up
    with_lock_retries do
      remove_foreign_key_if_exists(
        SOURCE_TABLE_NAME,
        TARGET_TABLE_NAME,
        name: FK_NAME,
        reverse_lock_order: true
      )
    end
  end

  def down
    add_concurrent_foreign_key(
      SOURCE_TABLE_NAME,
      TARGET_TABLE_NAME,
      column: COLUMN,
      target_column: TARGET_COLUMN,
      validate: true,
      reverse_lock_order: true,
      on_delete: :cascade,
      name: FK_NAME
    )
  end
end
