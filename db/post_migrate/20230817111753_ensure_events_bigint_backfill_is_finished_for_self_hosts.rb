# frozen_string_literal: true

class EnsureEventsBigintBackfillIsFinishedForSelfHosts < Gitlab::Database::Migration[2.1]
  include Gitlab::Database::MigrationHelpers::ConvertToBigint

  restrict_gitlab_migration gitlab_schema: :gitlab_main
  disable_ddl_transaction!

  def up
    ensure_batched_background_migration_is_finished(
      job_class_name: 'CopyColumnUsingBackgroundMigrationJob',
      table_name: 'events',
      column_name: 'id',
      job_arguments: [['target_id'], ['target_id_convert_to_bigint']]
    )
  end

  def down
    # no-op
  end
end
