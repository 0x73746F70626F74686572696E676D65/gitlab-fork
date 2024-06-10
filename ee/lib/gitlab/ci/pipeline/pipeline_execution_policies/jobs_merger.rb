# frozen_string_literal: true

# This class is responsible for injecting jobs from Pipeline Execution Policies into the project pipeline.
# It injects a stage into the pipeline as long as it is included in the declared stages.
#
# In `pipeline.stages`, we have positions that match the index of the declared stage.
# If a stage is not used in the project pipeline but it was declared, we have a position gap
# where we can inject the stage without creating position conflicts.
module Gitlab
  module Ci
    module Pipeline
      module PipelineExecutionPolicies
        class JobsMerger
          include ::Gitlab::Utils::StrongMemoize

          def initialize(pipeline:, execution_policy_pipelines:, declared_stages:)
            @pipeline = pipeline
            @execution_policy_pipelines = execution_policy_pipelines
            @declared_stages = declared_stages
            @pipeline_stages_by_name = pipeline.stages.index_by(&:name)
          end

          def execute
            execution_policy_pipelines.each do |policy_pipeline_config|
              inject_jobs_from(policy_pipeline_config)
            end
          end

          private

          attr_reader :pipeline, :execution_policy_pipelines, :declared_stages, :pipeline_stages_by_name

          def inject_jobs_from(policy_pipeline)
            policy_pipeline.stages.each do |policy_stage|
              ensure_stage_exists(policy_stage)
              matching_pipeline_stage = pipeline_stages_by_name[policy_stage.name]

              # If a policy configuration uses a stage that does not exist in the
              # project pipeline we silently ignore all the policy jobs in it.
              next unless matching_pipeline_stage

              insert_jobs(
                from_stage: policy_stage,
                to_stage: matching_pipeline_stage
              )
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

          def ensure_stage_exists(policy_stage)
            return if pipeline_stages_by_name[policy_stage.name].present?
            return unless stage_declared_in_project_config?(policy_stage)

            pipeline_stage = insert_stage_into_pipeline(policy_stage)
            pipeline_stages_by_name[pipeline_stage.name] = pipeline_stage
          end

          def declared_stages_positions
            declared_stages.each_with_index.to_h
          end
          strong_memoize_attr :declared_stages_positions

          def stage_declared_in_project_config?(policy_stage)
            declared_stages_positions.key?(policy_stage.name)
          end

          def insert_stage_into_pipeline(policy_stage)
            policy_stage.dup.tap do |stage|
              position = declared_stages_positions[stage.name]
              stage.assign_attributes(pipeline: pipeline, position: position)
              pipeline.stages << stage
            end
          end
        end
      end
    end
  end
end
