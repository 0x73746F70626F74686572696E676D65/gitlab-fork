# frozen_string_literal: true

RSpec.shared_context 'with pipeline policy context' do
  let(:pipeline_policy_context) do
    Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext.new(project: project, command: command)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      execution_policy_dry_run: execution_policy_dry_run,
      execution_policy_pipelines: execution_policy_pipelines
    )
  end

  let_it_be(:project) { create(:project, :repository) }
  let(:execution_policy_dry_run) { false }
  let(:execution_policy_pipelines) { [] }
end
