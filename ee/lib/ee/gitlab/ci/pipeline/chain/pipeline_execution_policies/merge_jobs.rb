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
              def perform!
                return if ::Feature.disabled?(:pipeline_execution_policy_type, project.group)
                return if command.execution_policy_mode? || command.execution_policy_pipelines.blank?

                clear_project_pipeline
                merge_policy_jobs
              end

              def break?
                pipeline.errors.any?
              end

              private

              def clear_project_pipeline
                # We need to remove the DUMMY job from the pipeline which was added to
                # enforce the pipeline without project CI configuration.
                pipeline.stages = [] if pipeline.pipeline_execution_policy_forced?
              end

              def merge_policy_jobs
                ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger
                  .new(pipeline: pipeline,
                    execution_policy_pipelines: command.execution_policy_pipelines,
                    # `yaml_processor_result` contains the declared project stages, even if they are unused.
                    declared_stages: command.yaml_processor_result.stages
                  )
                  .execute
              end
            end
          end
        end
      end
    end
  end
end
