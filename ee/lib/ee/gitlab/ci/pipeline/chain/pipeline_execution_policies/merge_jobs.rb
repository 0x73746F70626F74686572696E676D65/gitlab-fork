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
                return if command.execution_policy_mode? || command.pipeline_execution_policies.blank?

                clear_project_pipeline
                merge_policy_jobs
              end

              def break?
                pipeline.errors.any?
              end

              private

              def clear_project_pipeline
                # We remove the project pipeline config in two scenarios;
                # 1. pipeline_execution_policy_forced?: It means that it is only
                # the DUMMY job to enforce the pipeline without project CI configuration.
                # 2. any policy uses `override_project_ci` strategy.
                # It means that we need to ignore the project CI configuration.
                return unless pipeline.pipeline_execution_policy_forced? || override_project_ci_strategy_enforced?

                pipeline.stages = []
              end

              def override_project_ci_strategy_enforced?
                command.pipeline_execution_policies.any?(&:strategy_override_project_ci?)
              end

              def merge_policy_jobs
                ::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger
                  .new(pipeline: pipeline,
                    pipeline_execution_policies: command.pipeline_execution_policies,
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
