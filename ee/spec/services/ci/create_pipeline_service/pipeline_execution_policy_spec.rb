# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do
  include RepoHelpers

  subject(:execute) { service.execute(:push) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be_with_reload(:compliance_project) { create(:project, :empty_repo, group: group) }
  let_it_be(:user) { create(:user, developer_of: [project, compliance_project]) }

  let(:namespace_policy_content) { { namespace_policy_job: { stage: 'build', script: 'namespace script' } } }
  let(:namespace_policy_file) { 'namespace-policy.yml' }
  let(:namespace_policy) do
    build(:pipeline_execution_policy,
      content: { include: [{
        project: compliance_project.full_path,
        file: namespace_policy_file,
        ref: compliance_project.default_branch_or_main
      }] })
  end

  let(:namespace_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [namespace_policy])
  end

  let_it_be_with_reload(:namespace_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be(:namespace_configuration) do
    create(:security_orchestration_policy_configuration,
      project: nil, namespace: group, security_policy_management_project: namespace_policies_project)
  end

  let(:project_policy_content) { { project_policy_job: { script: 'project script' } } }
  let(:project_policy_file) { 'project-policy.yml' }
  let(:project_policy) do
    build(:pipeline_execution_policy,
      content: { include: [{
        project: compliance_project.full_path,
        file: project_policy_file,
        ref: compliance_project.default_branch_or_main
      }] })
  end

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
          create_and_delete_files(
            compliance_project, {
              project_policy_file => project_policy_content.to_yaml,
              namespace_policy_file => namespace_policy_content.to_yaml
            }
          ) do
            example.run
          end
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

  context 'when policy content does not match the valid schema' do
    # A valid `content` should reference an external file via `include` and not include the jobs in the policy directly
    # The schema is defined in `ee/app/validators/json_schemas/security_orchestration_policy.json`.
    let(:namespace_policy) { build(:pipeline_execution_policy, content: namespace_policy_content) }
    let(:project_policy) { build(:pipeline_execution_policy, content: project_policy_content) }

    it 'responds with success' do
      expect(execute).to be_success
    end

    it 'persists pipeline' do
      expect(execute.payload).to be_persisted
    end

    it 'only includes project jobs and ignores the invalid policy jobs', :aggregate_failures do
      expect { execute }.to change { Ci::Build.count }.from(0).to(2)

      stages = execute.payload.stages
      expect(stages.map(&:name)).to contain_exactly('build', 'test')

      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec')
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

  context 'when commit contains a [ci skip] directive' do
    before do
      allow_next_instance_of(Ci::Pipeline) do |instance|
        allow(instance).to receive(:git_commit_message).and_return('some message[ci skip]')
      end
    end

    it 'does not skip pipeline creation and injects policy jobs' do
      expect { execute }.to change { Ci::Build.count }.from(0).to(4)

      stages = execute.payload.stages
      expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build', 'namespace_policy_job')
      expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec', 'project_policy_job')
    end
  end
end
