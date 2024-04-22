# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::MergeJobs, feature_category: :security_policy_management do
  include Ci::PipelineExecutionPolicyHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, project: project, ref: 'master', user: user) }
  let(:execution_policy_pipelines) do
    [
      build_mock_policy_pipeline({ 'build' => ['docker'] }),
      build_mock_policy_pipeline({ 'test' => ['rspec'] })
    ]
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: pipeline.ref,
      execution_policy_pipelines: execution_policy_pipelines
    )
  end

  let(:step) { described_class.new(pipeline, command) }

  let(:config) do
    { build_job: { stage: 'build', script: 'docker build .' },
      rake: { stage: 'test', script: 'rake' } }
  end

  subject(:run_chain) do
    run_previous_chain(pipeline, command)
    perform_chain(pipeline, command)
  end

  before do
    stub_ci_pipeline_yaml_file(YAML.dump(config)) if config
  end

  describe '#perform!' do
    it 'reassigns jobs to the correct stage using JobsMerger', :aggregate_failures do
      expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger)
        .to receive(:new).with(
          pipeline: pipeline,
          execution_policy_pipelines: execution_policy_pipelines,
          declared_stages: %w[.pre build test deploy .post]
        ).and_call_original

      run_chain

      build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
      expect(build_stage.statuses.map(&:name)).to contain_exactly('build_job', 'docker')

      test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
      expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
    end

    context 'when project CI configuration declares custom stages' do
      let(:config) do
        { stages: %w[pre-test test post-test],
          rake: { stage: 'test', script: 'rake' } }
      end

      it 'passes down the declared stages to the JobsMerger' do
        expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger)
          .to receive(:new).with(
            pipeline: pipeline,
            execution_policy_pipelines: execution_policy_pipelines,
            declared_stages: %w[.pre pre-test test post-test .post]
          ).and_call_original

        run_chain
      end
    end

    context 'when there is no project CI configuration' do
      let(:config) { nil }

      it 'removes the dummy job that forced the pipeline creation and only keeps policy jobs in default stages' do
        expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger)
          .to receive(:new).with(
            pipeline: pipeline,
            execution_policy_pipelines: execution_policy_pipelines,
            declared_stages: %w[.pre build test deploy .post]
          ).and_call_original

        run_chain

        expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')

        build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
        expect(build_stage.statuses.map(&:name)).to contain_exactly('docker')

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rspec')
      end
    end

    context 'when feature flag "pipeline_execution_policy_type" is disabled' do
      before do
        stub_feature_flags(pipeline_execution_policy_type: false)
      end

      it 'does not change pipeline stages' do
        expect { run_chain }.not_to change { pipeline.stages }
      end
    end

    context 'when execution_policy_pipelines is not defined' do
      let(:execution_policy_pipelines) { nil }

      it 'does not change pipeline stages' do
        expect { run_chain }.not_to change { pipeline.stages }
      end
    end

    private

    def run_previous_chain(pipeline, command)
      [
        Gitlab::Ci::Pipeline::Chain::Config::Content.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Config::Process.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::EvaluateWorkflowRules.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Seed.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Populate.new(pipeline, command)
      ].map(&:perform!)
    end

    def perform_chain(pipeline, command)
      described_class.new(pipeline, command).perform!
    end
  end
end
