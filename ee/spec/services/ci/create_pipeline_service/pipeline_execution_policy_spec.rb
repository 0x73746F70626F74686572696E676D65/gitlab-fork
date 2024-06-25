# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do
  include RepoHelpers

  subject(:execute) { service.execute(:push, **opts) }

  let(:opts) { {} }
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

  describe 'reserved stages' do
    context 'when policy pipelines use reserved stages' do
      let(:namespace_policy_content) do
        { namespace_pre_job: { stage: '.pipeline-policy-pre', script: 'pre script' } }
      end

      let(:project_policy_content) do
        { project_post_job: { stage: '.pipeline-policy-post', script: 'post script' } }
      end

      it 'responds with success' do
        expect(execute).to be_success
      end

      it 'persists pipeline' do
        expect(execute.payload).to be_persisted
      end

      it 'persists jobs in the reserved stages', :aggregate_failures do
        expect { execute }.to change { Ci::Build.count }.from(0).to(4)

        stages = execute.payload.stages
        expect(stages.map(&:name)).to contain_exactly('.pipeline-policy-pre', 'build', 'test', '.pipeline-policy-post')

        expect(stages.find_by(name: '.pipeline-policy-pre').builds.map(&:name)).to contain_exactly('namespace_pre_job')
        expect(stages.find_by(name: 'build').builds.map(&:name)).to contain_exactly('build')
        expect(stages.find_by(name: 'test').builds.map(&:name)).to contain_exactly('rspec')
        expect(stages.find_by(name: '.pipeline-policy-post').builds.map(&:name)).to contain_exactly('project_post_job')
      end
    end

    context 'when reserved stages are declared in project CI YAML' do
      let(:project_ci_yaml) do
        <<~YAML
          pre-compliance:
            stage: .pipeline-policy-pre
            script:
              - echo 'pre'
          rspec:
            stage: test
            script:
              - echo 'rspec'
          post-compliance:
            stage: .pipeline-policy-post
            script:
              - echo 'post'
        YAML
      end

      it 'responds with error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.payload).to be_persisted
        expect(execute.payload.errors.full_messages)
          .to contain_exactly(
            'pre-compliance job: chosen stage `.pipeline-policy-pre` is reserved for Pipeline Execution Policies'
          )
      end
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

  describe 'variables precedence' do
    let(:opts) { { variables_attributes: [{ key: 'TEST_TOKEN', value: 'run token' }] } }
    let(:project_ci_yaml) do
      <<~YAML
        variables:
          TEST_TOKEN: 'global token'
        project-build:
          stage: build
          variables:
            TEST_TOKEN: 'job token'
          script:
            - echo 'build'
        project-test:
          stage: test
          script:
            - echo 'test'
      YAML
    end

    let(:project_policy_content) do
      {
        project_policy_job: {
          variables: { 'TEST_TOKEN' => 'project policy token' },
          script: 'project script'
        }
      }
    end

    let(:namespace_policy_content) do
      {
        namespace_policy_job: {
          variables: { 'TEST_TOKEN' => 'namespace policy token', 'POLICY_TOKEN' => 'namespace policy token' },
          script: 'namespace script'
        }
      }
    end

    it 'applies the policy variables in policy jobs with highest precedence', :aggregate_failures do
      stages = execute.payload.stages

      build_stage = stages.find_by(name: 'build')
      test_stage = stages.find_by(name: 'test')

      project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
      expect(get_job_variable(project_policy_job, 'TEST_TOKEN')).to eq('project policy token')

      namespace_policy_job = test_stage.builds.find_by(name: 'namespace_policy_job')
      expect(get_job_variable(namespace_policy_job, 'TEST_TOKEN')).to eq('namespace policy token')

      project_build_job = build_stage.builds.find_by(name: 'project-build')
      expect(get_job_variable(project_build_job, 'TEST_TOKEN')).to eq('run token')

      project_test_job = test_stage.builds.find_by(name: 'project-test')
      expect(get_job_variable(project_test_job, 'TEST_TOKEN')).to eq('run token')
    end

    it 'does not leak policy variables into the project jobs and other policy jobs', :aggregate_failures do
      stages = execute.payload.stages

      build_stage = stages.find_by(name: 'build')
      test_stage = stages.find_by(name: 'test')

      project_policy_job = test_stage.builds.find_by(name: 'project_policy_job')
      expect(get_job_variable(project_policy_job, 'POLICY_TOKEN')).to be_nil

      namespace_policy_job = test_stage.builds.find_by(name: 'namespace_policy_job')
      expect(get_job_variable(namespace_policy_job, 'POLICY_TOKEN')).to eq('namespace policy token')

      project_build_job = build_stage.builds.find_by(name: 'project-build')
      expect(get_job_variable(project_build_job, 'POLICY_TOKEN')).to be_nil

      project_test_job = test_stage.builds.find_by(name: 'project-test')
      expect(get_job_variable(project_test_job, 'POLICY_TOKEN')).to be_nil
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

  private

  def get_job_variable(job, key)
    job.scoped_variables.to_hash[key]
  end
end
