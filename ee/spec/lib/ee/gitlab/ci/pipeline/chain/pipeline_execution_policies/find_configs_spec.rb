# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::FindConfigs, feature_category: :security_policy_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, project: project, ref: 'master', user: user) }

  let(:execution_policy_dry_run) { nil }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: pipeline.ref,
      execution_policy_dry_run: execution_policy_dry_run
    )
  end

  let(:step) { described_class.new(pipeline, command) }

  let(:namespace_content) do
    { job: { script: 'namespace script' } }.to_yaml
  end

  let(:project_content) do
    { job: { script: 'project script' } }.to_yaml
  end

  let(:policy_contents) { [namespace_content, project_content] }

  before do
    allow_next_instance_of(::Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies) do |instance|
      allow(instance).to receive(:configs).and_return(policy_contents)
    end
  end

  describe '#perform!' do
    it 'sets execution_policy_pipelines' do
      step.perform!

      expect(command.execution_policy_pipelines).to be_a(Array)
      expect(command.execution_policy_pipelines.size).to eq(2)
    end

    context 'with merge_request parameter set on the command' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let(:command) do
        Gitlab::Ci::Pipeline::Chain::Command.new(
          project: project,
          current_user: user,
          origin_ref: merge_request.ref_path,
          merge_request: merge_request
        )
      end

      let(:project_content) do
        { job: { script: 'project script', rules: [{ when: 'always' }] } }.to_yaml
      end

      it 'passes the merge request to the policy pipelines' do
        step.perform!

        expect(command.execution_policy_pipelines.first.merge_request).to eq(merge_request)
      end
    end

    context 'when there is an error in pipeline execution policies' do
      let(:project_content) do
        { job: {} }.to_yaml
      end

      before do
        step.perform!
      end

      it 'breaks the processing chain' do
        expect(step.break?).to be true
      end

      it 'does not save the pipeline' do
        expect(pipeline).not_to be_persisted
      end

      it 'returns a specific error' do
        expect(pipeline.errors[:base]).to include(a_string_including('Pipeline execution policy error'))
      end
    end

    context 'when the policy pipeline gets filtered out by rules' do
      let(:namespace_content) do
        { job: { script: 'namespace script', rules: [{ if: '$CI_COMMIT_REF_NAME == "invalid"' }] } }.to_yaml
      end

      let(:project_content) do
        { job: { script: 'project script', rules: [{ if: '$CI_COMMIT_REF_NAME == "invalid"' }] } }.to_yaml
      end

      before do
        step.perform!
      end

      it 'does not break the processing chain' do
        expect(step.break?).to be false
      end

      it 'ignores the policy pipelines' do
        expect(command.execution_policy_pipelines).to be_empty
      end
    end

    context 'when feature flag "pipeline_execution_policy_type" is disabled' do
      before do
        stub_feature_flags(pipeline_execution_policy_type: false)
      end

      it 'does not set execution_policy_pipelines' do
        step.perform!

        expect(command.execution_policy_pipelines).to be_nil
      end
    end

    context 'when running in execution_policy_dry_run' do
      let(:execution_policy_dry_run) { true }

      it 'does not set execution_policy_pipelines' do
        step.perform!

        expect(command.execution_policy_pipelines).to be_nil
      end
    end

    context 'when pipeline execution policy configs are empty' do
      let(:policy_contents) { [] }

      it 'does not set execution_policy_pipelines' do
        step.perform!

        expect(command.execution_policy_pipelines).to be_nil
      end
    end
  end
end
