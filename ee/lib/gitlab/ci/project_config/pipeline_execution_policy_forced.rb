# frozen_string_literal: true

module Gitlab
  module Ci
    class ProjectConfig
      # This class is responsible for generating the content of the `.gitlab-ci.yml`
      # file that will trigger the execution of the pipeline execution policy jobs.
      #
      # If there are Pipeline Execution Policies defined for a project,
      # this source will generate a dummy job that will force the creation
      # of the project pipeline, so that the execution policy jobs can be merged
      # into it. The dummy job will be removed in `MergeJobs` step of the pipeline chain.
      #
      # This source should be loaded before AutoDevops source.
      class PipelineExecutionPolicyForced < Gitlab::Ci::ProjectConfig::Source
        DUMMY_CONTENT = {
          'Pipeline execution policy trigger' => {
            'stage' => ::Gitlab::Ci::Config::EdgeStagesInjector::PRE_PIPELINE,
            'script' => ['echo "Forcing project pipeline to run policy jobs."']
          }
        }.freeze

        def content
          return if ::Feature.disabled?(:pipeline_execution_policy_type, @project.group)
          return unless @has_execution_policy_pipelines

          # Create a dummy job to ensure that project pipeline gets created.
          # Pipeline execution policy jobs will be merged onto the project pipeline.
          YAML.dump(DUMMY_CONTENT)
        end
        strong_memoize_attr :content

        def source
          :pipeline_execution_policy_forced
        end
      end
    end
  end
end
