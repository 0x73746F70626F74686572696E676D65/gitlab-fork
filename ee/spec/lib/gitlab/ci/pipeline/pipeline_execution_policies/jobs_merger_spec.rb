# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger, feature_category: :security_policy_management do
  include Ci::PipelineExecutionPolicyHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:declared_stages) { %w[.pipeline-policy-pre .pre build test deploy .post .pipeline-policy-post] }
  let(:pipeline) { build_mock_pipeline({ 'build' => ['build_job'], 'test' => ['rake'] }, declared_stages) }
  let(:pipeline_execution_policies) do
    [
      build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'build' => ['docker'] })),
      build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
    ]
  end

  subject(:execute) do
    described_class.new(
      pipeline: pipeline,
      pipeline_execution_policies: pipeline_execution_policies,
      declared_stages: declared_stages
    ).execute
  end

  it 'reassigns jobs to the correct stage', :aggregate_failures do
    execute

    build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
    expect(build_stage.statuses.map(&:name)).to contain_exactly('build_job', 'docker')

    test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
    expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
  end

  it 'marks the jobs as execution_policy_jobs' do
    execute

    test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
    project_rake_job = test_stage.statuses.find { |status| status.name == 'rake' }
    policy_rspec_job = test_stage.statuses.find { |status| status.name == 'rspec' }

    expect(project_rake_job.execution_policy_job?).to eq(false)
    expect(policy_rspec_job.execution_policy_job?).to eq(true)
  end

  context 'with conflicting jobs' do
    context 'when two policy pipelines have the same job names' do
      let(:pipeline_execution_policies) do
        [
          build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] })),
          build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
        ]
      end

      it 'injects both jobs to the correct stage', :aggregate_failures do
        execute

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.statuses.size).to eq(3)
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec', 'rspec')
      end
    end

    context 'when project and policy pipelines have the same job names' do
      let(:pipeline_execution_policies) do
        [
          build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'test' => ['rake'] })),
          build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
        ]
      end

      it 'injects the jobs while keeping the project job', :aggregate_failures do
        execute

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.statuses.size).to eq(3)
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rake', 'rspec')
      end
    end
  end

  context 'when policy defines additional stages' do
    context 'when custom policy stage is also defined but not used in the main pipeline' do
      let(:declared_stages) { %w[.pipeline-policy-pre .pre build test custom .post .pipeline-policy-post] }

      let(:pipeline_execution_policies) do
        build_list(:ci_pipeline_execution_policy, 1, pipeline: build_mock_policy_pipeline({ 'custom' => ['docker'] }))
      end

      it 'injects the policy job into the custom stage', :aggregate_failures do
        execute

        expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test', 'custom')

        custom_stage = pipeline.stages.find { |stage| stage.name == 'custom' }
        expect(custom_stage.position).to eq(4)
        expect(custom_stage.statuses.map(&:name)).to contain_exactly('docker')
      end
    end

    context 'when custom policy stage is not defined in the main pipeline' do
      let(:pipeline_execution_policies) do
        build_list(:ci_pipeline_execution_policy, 1, pipeline: build_mock_policy_pipeline({ 'custom' => ['docker'] }))
      end

      it 'ignores the stage' do
        execute

        expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')
      end
    end
  end

  context 'when the policy stage is defined in a different position than the stage in the main pipeline' do
    let(:declared_stages) { %w[.pipeline-policy-pre .pre build test .post .pipeline-policy-post] }
    let(:pipeline_execution_policies) do
      build_list(:ci_pipeline_execution_policy, 1, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
    end

    it 'reassigns the position and stage_idx for the jobs to match the main pipeline', :aggregate_failures do
      execute

      test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
      expect(test_stage.position).to eq(3)
      expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
      expect(test_stage.statuses.map(&:stage_idx)).to all(eq(test_stage.position))
    end
  end

  context 'when there are gaps in the main pipeline stages due to them being unused' do
    let(:declared_stages) { %w[.pipeline-policy-pre .pre build test deploy .post .pipeline-policy-post] }
    let(:pipeline) { build_mock_pipeline({ 'deploy' => ['package'] }, declared_stages) }

    let(:pipeline_execution_policies) do
      build_list(:ci_pipeline_execution_policy, 1, pipeline: build_mock_policy_pipeline({ 'deploy' => ['docker'] }))
    end

    it 'reassigns the position and stage_idx for policy jobs based on the declared stages', :aggregate_failures do
      execute

      expect(pipeline.stages.map(&:name)).to contain_exactly('deploy')

      deploy_stage = pipeline.stages.find { |stage| stage.name == 'deploy' }
      expect(deploy_stage.position).to eq(4)
      expect(deploy_stage.statuses.map(&:name)).to contain_exactly('package', 'docker')
      expect(deploy_stage.statuses.map(&:stage_idx)).to all(eq(deploy_stage.position))
    end
  end

  context 'when pipeline_execution_policies is empty' do
    let(:pipeline_execution_policies) { [] }

    it 'does not change pipeline stages' do
      expect { execute }.not_to change { pipeline.stages }
    end
  end
end
