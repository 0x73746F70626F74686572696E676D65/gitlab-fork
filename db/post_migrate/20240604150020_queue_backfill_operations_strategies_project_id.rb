# frozen_string_literal: true

class QueueBackfillOperationsStrategiesProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.1'
  restrict_gitlab_migration gitlab_schema: :gitlab_main_cell

  MIGRATION = "BackfillOperationsStrategiesProjectId"
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 1000
  SUB_BATCH_SIZE = 100

  def up
    queue_batched_background_migration(
      MIGRATION,
      :operations_strategies,
      :id,
      :project_id,
      :operations_feature_flags,
      :project_id,
      :feature_flag_id,
      job_interval: DELAY_INTERVAL,
      batch_size: BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE
    )
  end

  def down
    delete_batched_background_migration(
      MIGRATION,
      :operations_strategies,
      :id,
      [
        :project_id,
        :operations_feature_flags,
        :project_id,
        :feature_flag_id
      ]
    )
  end
end
