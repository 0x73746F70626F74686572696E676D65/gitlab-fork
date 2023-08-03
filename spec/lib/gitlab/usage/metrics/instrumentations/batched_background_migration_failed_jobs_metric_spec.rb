# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::BatchedBackgroundMigrationFailedJobsMetric, feature_category: :database do
  let(:expected_value) do
    [
      {
        job_class_name: 'job',
        number_of_failed_jobs: 1,
        table_name: 'jobs'
      },
      {
        job_class_name: 'test',
        number_of_failed_jobs: 2,
        table_name: 'users'
      }
    ]
  end

  let_it_be(:active_migration) do
    create(:batched_background_migration, :active, table_name: 'users', job_class_name: 'test', created_at: 5.days.ago)
  end

  let_it_be(:failed_migration) do
    create(:batched_background_migration, :failed, table_name: 'jobs', job_class_name: 'job', created_at: 4.days.ago)
  end

  let_it_be(:batched_job) { create(:batched_background_migration_job, :failed, batched_migration: active_migration) }

  let_it_be(:batched_job_2) { create(:batched_background_migration_job, :failed, batched_migration: active_migration) }

  let_it_be(:batched_job_3) { create(:batched_background_migration_job, :failed, batched_migration: failed_migration) }

  let_it_be(:old_migration) { create(:batched_background_migration, :failed, created_at: 99.days.ago) }

  let_it_be(:old_batched_job) { create(:batched_background_migration_job, :failed, batched_migration: old_migration) }

  it_behaves_like 'a correct instrumented metric value', { time_frame: '7d' }
end
