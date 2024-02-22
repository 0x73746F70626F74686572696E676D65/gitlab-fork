# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::MergeJobs, feature_category: :security_policy_management do
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
    stub_ci_pipeline_yaml_file(YAML.dump(config))
  end

  describe '#perform!' do
    it 'reassigns jobs to the correct stage and assigns policy index to their name', :aggregate_failures do
      run_chain

      build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
      expect(build_stage.statuses.map(&:name)).to contain_exactly('build_job', 'docker')

      test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
      expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
    end

    context 'with conflicting jobs' do
      context 'when two policy pipelines have the same job names' do
        let(:execution_policy_pipelines) do
          [
            build_mock_policy_pipeline({ 'test' => ['rspec'] }),
            build_mock_policy_pipeline({ 'test' => ['rspec'] })
          ]
        end

        it 'injects both jobs to the correct stage', :aggregate_failures do
          run_chain

          test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
          expect(test_stage.statuses.size).to eq(3)
          expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec', 'rspec')
        end
      end

      context 'when project and policy pipelines have the same job names' do
        let(:execution_policy_pipelines) do
          [
            build_mock_policy_pipeline({ 'test' => ['rake'] }),
            build_mock_policy_pipeline({ 'test' => ['rspec'] })
          ]
        end

        it 'injects the jobs while keeping the project job', :aggregate_failures do
          run_chain

          test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
          expect(test_stage.statuses.size).to eq(3)
          expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rake', 'rspec')
        end
      end
    end

    context 'when policy defines additional stages' do
      context 'when custom policy stage is also defined but not used in the main pipeline' do
        let(:config) do
          { stages: %w[build test custom],
            rspec: { stage: 'test', script: 'rake' },
            build: { stage: 'build', script: 'make .' } }
        end

        let(:execution_policy_pipelines) do
          [build_mock_policy_pipeline({ 'custom' => ['docker'] })]
        end

        it 'ignores the job in the custom stage' do
          run_chain

          expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')
        end
      end

      context 'when custom policy stage is not defined in the main pipeline' do
        let(:execution_policy_pipelines) do
          [build_mock_policy_pipeline({ 'custom' => ['docker'] })]
        end

        before do
          run_chain
        end

        it 'does not break the processing chain' do
          expect(step.break?).to eq(false)
        end

        it 'ignores the stage' do
          expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')
        end
      end
    end

    context 'when the policy stage is defined in a different position than the stage in the main pipeline' do
      let(:config) do
        { stages: %w[build test],
          rake: { stage: 'test', script: 'rake' },
          build: { stage: 'build', script: 'make .' } }
      end

      let(:execution_policy_pipelines) do
        [build_mock_policy_pipeline({ 'test' => ['rspec'] })]
      end

      it 'reassigns the position and stage_idx for the jobs to match the main pipeline', :aggregate_failures do
        run_chain

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.position).to eq(2) # pipeline contains [.pre build test]
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
        expect(test_stage.statuses.map(&:stage_idx)).to all(eq(test_stage.position))
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

    context 'when running in execution_policy_pipelines is empty' do
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

    def build_mock_policy_pipeline(config)
      build(:ci_pipeline, project: project).tap do |pipeline|
        pipeline.stages = config.map.with_index do |(stage, builds), index|
          build(:ci_stage, name: stage, pipeline: pipeline).tap do |s|
            s.statuses = builds.map { |name| build(:ci_build, name: name, stage_idx: index, pipeline: pipeline) }
          end
        end
      end
    end
  end
end
