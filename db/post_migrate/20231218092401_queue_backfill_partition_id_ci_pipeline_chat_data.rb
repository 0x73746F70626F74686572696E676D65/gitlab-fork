# frozen_string_literal: true

class QueueBackfillPartitionIdCiPipelineChatData < Gitlab::Database::Migration[2.2]
  milestone '16.8'
  restrict_gitlab_migration gitlab_schema: :gitlab_ci

  MIGRATION = 'BackfillPartitionIdCiPipelineChatData'
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 1000
  SUB_BATCH_SIZE = 100

  def up
    queue_batched_background_migration(
      MIGRATION,
      :ci_pipeline_chat_data,
      :id,
      job_interval: DELAY_INTERVAL,
      batch_size: BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :ci_pipeline_chat_data, :id, [])
  end
end
