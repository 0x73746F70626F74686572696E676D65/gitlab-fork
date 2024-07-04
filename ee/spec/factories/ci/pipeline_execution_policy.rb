# frozen_string_literal: true

FactoryBot.define do
  factory(
    :ci_pipeline_execution_policy,
    class: '::Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::FindConfigs::PipelineExecutionPolicy'
  ) do
    pipeline factory: :ci_empty_pipeline
  end
end
