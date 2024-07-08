# frozen_string_literal: true

class FkCiPipelinesCiDailyBuildGroupReportResultsOnParIdLastPipelineId < Gitlab::Database::Migration[2.2]
  milestone '17.2'
  disable_ddl_transaction!

  SOURCE_TABLE_NAME = :ci_daily_build_group_report_results
  TARGET_TABLE_NAME = :ci_pipelines
  COLUMN = :last_pipeline_id
  TARGET_COLUMN = :id
  FK_NAME = :fk_rails_ee072d13b3_p
  PARTITION_COLUMN = :partition_id

  def up
    add_concurrent_foreign_key(
      SOURCE_TABLE_NAME,
      TARGET_TABLE_NAME,
      column: [PARTITION_COLUMN, COLUMN],
      target_column: [PARTITION_COLUMN, TARGET_COLUMN],
      validate: false,
      reverse_lock_order: true,
      on_update: :cascade,
      on_delete: :cascade,
      name: FK_NAME
    )
  end

  def down
    with_lock_retries do
      remove_foreign_key_if_exists(
        SOURCE_TABLE_NAME,
        TARGET_TABLE_NAME,
        name: FK_NAME,
        reverse_lock_order: true
      )
    end
  end
end
