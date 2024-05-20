# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillFindingInitialPipelineId
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          scope_to ->(relation) do
            relation.where(initial_pipeline_id: nil).or(
              relation.where(latest_pipeline_id: nil)
            )
          end
          operation_name :backfill_finding_initial_and_latest_pipeline_id
          feature_category :vulnerability_management
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            connection.exec_update(update_initial_sql(sub_batch))
            connection.exec_update(update_latest_sql(sub_batch))
          end
        end

        private

        def update_initial_sql(sub_batch)
          <<~SQL
          WITH cte AS (
             SELECT
                 occurrence_pipelines.*
             FROM
                 vulnerability_occurrences,
                 LATERAL (
                     SELECT
                         occurrence_id,
                         pipeline_id
                     FROM
                         vulnerability_occurrence_pipelines
                     WHERE
                         vulnerability_occurrence_pipelines.occurrence_id = vulnerability_occurrences.id
                     ORDER BY
                         pipeline_id ASC
                     LIMIT 1) AS occurrence_pipelines
             WHERE
                 vulnerability_occurrences.id IN (#{sub_batch.select(:id).to_sql}))
         UPDATE
             vulnerability_occurrences f
         SET
             initial_pipeline_id = c.pipeline_id
         FROM
             cte c
         WHERE
              f.id = c.occurrence_id
          SQL
        end

        def update_latest_sql(sub_batch)
          <<~SQL
          WITH cte AS (
             SELECT
                 occurrence_pipelines.*
             FROM
                 vulnerability_occurrences,
                 LATERAL (
                     SELECT
                         occurrence_id,
                         pipeline_id
                     FROM
                         vulnerability_occurrence_pipelines
                     WHERE
                         vulnerability_occurrence_pipelines.occurrence_id = vulnerability_occurrences.id
                     ORDER BY
                         pipeline_id DESC
                     LIMIT 1) AS occurrence_pipelines
             WHERE
                 vulnerability_occurrences.id IN (#{sub_batch.select(:id).to_sql}))
         UPDATE
             vulnerability_occurrences f
         SET
             latest_pipeline_id = c.pipeline_id
         FROM
             cte c
         WHERE
              f.id = c.occurrence_id
          SQL
        end
      end
    end
  end
end
