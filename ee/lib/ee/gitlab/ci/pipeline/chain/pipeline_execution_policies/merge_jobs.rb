# frozen_string_literal: true

# This step is only executed if Pipeline Execution Policies configurations were loaded in
# `PipelineExecutionPolicies::FindConfigs`, otherwise it's a no-op.
#
# It merges jobs from the policy pipelines saved on `command` onto the project pipeline.
# If a policy pipeline stage is not used in the project pipeline, all jobs from this stage are silently ignored.
#
# The step needs to be executed after `Populate` and `PopulateMetadata` steps to ensure that `pipeline.stages` are set,
# and before `StopDryRun` to ensure that the policy jobs are visible for the users when pipeline creation is simulated.
module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module PipelineExecutionPolicies
            module MergeJobs
              include ::Gitlab::Utils::StrongMemoize
              include ::Gitlab::Ci::Pipeline::Chain::Helpers
              extend ::Gitlab::Utils::Override

              def perform!
                return if ::Feature.disabled?(:pipeline_execution_policy_type, project.group)
                return if command.execution_policy_mode? || command.execution_policy_pipelines.blank?

                merge_policy_jobs
              end

              def break?
                pipeline.errors.any?
              end

              private

              def merge_policy_jobs
                command.execution_policy_pipelines.each do |policy_pipeline|
                  inject_jobs_from(policy_pipeline)
                end
              end

              def inject_jobs_from(policy_pipeline)
                pipeline_stages_by_name = pipeline.stages.index_by(&:name)
                policy_pipeline.stages.each do |policy_stage|
                  matching_pipeline_stage = pipeline_stages_by_name[policy_stage.name]

                  # If a policy configuration uses a stage that does not exist in the
                  # project pipeline we silently ignore all the policy jobs in it.
                  next unless matching_pipeline_stage

                  insert_jobs(from_stage: policy_stage, to_stage: matching_pipeline_stage)
                end
              end

              def insert_jobs(from_stage:, to_stage:)
                from_stage.statuses.each do |job|
                  # We need to assign the new stage_idx for the jobs
                  # because the policy stages could have had different positions
                  job.assign_attributes(pipeline: pipeline, stage_idx: to_stage.position)
                  to_stage.statuses << job
                end
              end
            end
          end
        end
      end
    end
  end
end
