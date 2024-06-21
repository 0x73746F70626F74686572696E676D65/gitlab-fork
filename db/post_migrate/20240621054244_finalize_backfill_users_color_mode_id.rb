# frozen_string_literal: true

class FinalizeBackfillUsersColorModeId < Gitlab::Database::Migration[2.2]
  milestone '17.2'

  disable_ddl_transaction!

  restrict_gitlab_migration gitlab_schema: :gitlab_main

  def up
    ensure_batched_background_migration_is_finished(
      job_class_name: 'BackfillUsersColorModeId',
      table_name: TABLE_NAME,
      column_name: BATCH_COLUMN,
      job_arguments: [],
      finalize: true
    )
  end

  def down; end
end
