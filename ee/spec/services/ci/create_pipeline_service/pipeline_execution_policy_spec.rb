# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do
  include RepoHelpers

  subject(:execute) { service.execute(:push) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:namespace_policy_content) { { namespace_policy_job: { stage: 'build', script: 'namespace script' } } }
  let(:namespace_policy) { build(:pipeline_execution_policy, content: namespace_policy_content) }
  let(:namespace_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [namespace_policy])
  end

  let_it_be_with_reload(:namespace_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be(:namespace_configuration) do
    create(:security_orchestration_policy_configuration,
      project: nil, namespace: group, security_policy_management_project: namespace_policies_project)
  end

  let(:project_policy_content) { { project_policy_job: { script: 'project script' } } }
  let(:project_policy) { build(:pipeline_execution_policy, content: project_policy_content) }
  let(:project_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [project_policy])
  end

  let_it_be_with_reload(:project_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be(:project_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project, security_policy_management_project: project_policies_project)
  end

  let(:project_ci_yaml) do
    <<~YAML
      build:
        stage: build
        script:
          - echo 'build'
      rspec:
        stage: test
        script:
          -echo 'test'
    YAML
  end

  let(:service) { described_class.new(project, user, { ref: 'master' }) }

  around do |example|
    create_and_delete_files(project, { '.gitlab-ci.yml' => project_ci_yaml }) do
      create_and_delete_files(
        project_policies_project, { '.gitlab/security-policies/policy.yml' => project_policy_yaml }
      ) do
        create_and_delete_files(
          namespace_policies_project, { '.gitlab/security-policies/policy.yml' => namespace_policy_yaml }
        ) do
          example.run
        end
      end
    end
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  it 'responds with success' do
    expect(execute).to be_success
  end

  it 'persists pipeline' do
    expect(execute.payload).to be_persisted
  end

  it 'persists jobs in the correct stages', :aggregate_failures do
    expect { execute }.to change { Ci::Build.count }.from(0).to(4)

    stages = execute.payload.stages
    expect(stages.map(&:name)).to contain_exactly('build', 'test')

    expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
    expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec', 'project_policy_job')
  end

  context 'when policy pipeline stage is not defined in the main pipeline' do
    let(:project_ci_yaml) do
      <<~YAML
        stages:
          - build
        build:
          stage: build
          script:
            - echo 'build'
      YAML
    end

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists the pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'ignores the policy stage', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(2)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build')
      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
    end
  end

  context 'when policy pipelines use declared, but unused project stages' do
    let(:project_ci_yaml) do
      <<~YAML
        stages:
        - build
        - test
        rspec:
          stage: test
          script:
            - echo 'rspec'
      YAML
    end

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'persists jobs in the correct stages', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(3)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('namespace_policy_job')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec', 'project_policy_job')
    end
  end

  context 'when project CI configuration is missing' do
    let(:project_ci_yaml) { nil }

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'sets the correct config_source' do
      expect(execute.payload.config_source).to eq('pipeline_execution_policy_forced')
    end

    it 'injects the policy jobs', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(2)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('namespace_policy_job')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('project_policy_job')
    end
  end
end
