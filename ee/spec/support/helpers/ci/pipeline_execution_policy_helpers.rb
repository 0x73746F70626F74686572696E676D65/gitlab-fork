# frozen_string_literal: true

module Ci
  module PipelineExecutionPolicyHelpers
    def build_mock_policy_pipeline(config)
      build_mock_pipeline(config, config.keys)
    end

    def build_mock_pipeline(config, stages)
      build(:ci_pipeline, project: project).tap do |pipeline|
        pipeline.stages = config.map do |(stage, builds)|
          stage_idx = stages.index(stage)
          build(:ci_stage, name: stage, position: stage_idx, pipeline: pipeline).tap do |s|
            s.statuses = builds.map { |name| build(:ci_build, name: name, stage_idx: stage_idx, pipeline: pipeline) }
          end
        end
      end
    end
  end
end
