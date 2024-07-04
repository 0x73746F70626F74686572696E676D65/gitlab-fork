# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::FindConfigs, feature_category: :security_policy_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, source: source, project: project, ref: 'master', user: user) }
  let(:source) { 'push' }

  let(:execution_policy_dry_run) { nil }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      source: pipeline.source,
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
    it 'sets pipeline_execution_policies' do
      step.perform!

      expect(command.pipeline_execution_policies).to be_a(Array)
      expect(command.pipeline_execution_policies.size).to eq(2)
    end

    it 'passes pipeline source to execution policy pipelines' do
      step.perform!

      command.pipeline_execution_policies.each do |policy|
        expect(policy.pipeline.source).to eq(source)
      end
    end

    context 'with merge_request parameter set on the command' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let(:command) do
        Gitlab::Ci::Pipeline::Chain::Command.new(
          source: pipeline.source,
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

        expect(command.pipeline_execution_policies.first.pipeline.merge_request).to eq(merge_request)
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
        expect(command.pipeline_execution_policies).to be_empty
      end
    end

    context 'when feature flag "pipeline_execution_policy_type" is disabled' do
      before do
        stub_feature_flags(pipeline_execution_policy_type: false)
      end

      it 'does not set pipeline_execution_policies' do
        step.perform!

        expect(command.pipeline_execution_policies).to be_nil
      end
    end

    context 'when running in execution_policy_dry_run' do
      let(:execution_policy_dry_run) { true }

      it 'does not set pipeline_execution_policies' do
        step.perform!

        expect(command.pipeline_execution_policies).to be_nil
      end
    end

    context 'when policy should not be enforced for a source' do
      Enums::Ci::Pipeline.dangling_sources.each_key do |source|
        context "when source is #{source}" do
          let(:source) { source }

          it 'does not set pipeline_execution_policies' do
            step.perform!

            expect(command.pipeline_execution_policies).to be_nil
          end
        end
      end
    end

    context 'when pipeline execution policy configs are empty' do
      let(:policy_contents) { [] }

      it 'does not set pipeline_execution_policies' do
        step.perform!

        expect(command.pipeline_execution_policies).to be_nil
      end
    end
  end
end
