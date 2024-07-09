# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, '#execute', :saas, feature_category: :continuous_integration do
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:ultimate_plan) { create(:ultimate_plan) }
  let_it_be(:plan_limits) { create(:plan_limits, plan: ultimate_plan) }
  let_it_be(:project, reload: true) { create(:project, :repository, namespace: namespace) }
  let_it_be(:user) { create(:user) }

  let(:ref_name) { 'master' }

  let(:service) do
    params = { ref: ref_name,
               before: '00000000',
               after: project.commit.id,
               commits: [{ message: 'some commit' }] }

    described_class.new(project, user, params)
  end

  before do
    create(:gitlab_subscription, namespace: namespace, hosted_plan: ultimate_plan)

    project.add_developer(user)
    stub_ci_pipeline_to_return_yaml_file
  end

  describe 'CI/CD Quotas / Limits' do
    context 'when there are not limits enabled' do
      it 'enqueues a new pipeline', :aggregate_failures do
        response, pipeline = create_pipeline!

        expect(response).to be_success
        expect(pipeline).to be_created_successfully
      end
    end

    context 'when pipeline size limit is exceeded' do
      before do
        plan_limits.update_column(:ci_pipeline_size, 2)
      end

      it 'drops pipeline without creating jobs', :aggregate_failures do
        response, pipeline = create_pipeline!

        expect(response).to be_error
        expect(pipeline).to be_persisted
        expect(pipeline).to be_failed
        expect(pipeline.statuses).to be_empty
        expect(pipeline.size_limit_exceeded?).to be true
      end
    end
  end

  describe 'cross-project pipeline triggers' do
    before do
      stub_ci_pipeline_yaml_file <<~YAML
        test:
          script: rspec

        deploy:
          variables:
            CROSS: downstream
          stage: deploy
          trigger: my/project
      YAML
    end

    it 'creates bridge jobs correctly', :aggregate_failures do
      response, pipeline = create_pipeline!

      test = pipeline.statuses.find_by(name: 'test')
      bridge = pipeline.statuses.find_by(name: 'deploy')

      expect(response).to be_success
      expect(pipeline).to be_persisted
      expect(test).to be_a Ci::Build
      expect(bridge).to be_a Ci::Bridge
      expect(bridge.stage).to eq 'deploy'
      expect(pipeline.statuses).to match_array [test, bridge]
      expect(bridge.options).to eq(trigger: { project: 'my/project' })
      expect(bridge.yaml_variables)
        .to include(key: 'CROSS', value: 'downstream')
    end

    context 'when configured with rules' do
      before do
        stub_ci_pipeline_yaml_file(config)
      end

      let(:downstream_project) { create(:project, :repository) }

      let(:config) do
        <<-EOY
          hello:
            script: echo world

          bridge-job:
            rules:
              - if: $CI_COMMIT_REF_NAME == "master"
            trigger:
              project: #{downstream_project.full_path}
              branch: master
        EOY
      end

      context 'that include the bridge job' do
        it 'persists the bridge job' do
          _, pipeline = create_pipeline!

          expect(pipeline.processables.pluck(:name)).to contain_exactly('hello', 'bridge-job')
        end
      end

      context 'that exclude the bridge job' do
        let(:ref_name) { 'refs/heads/wip' }

        it 'does not include the bridge job' do
          _, pipeline = create_pipeline!

          expect(pipeline.processables.pluck(:name)).to eq(%w[hello])
        end
      end
    end
  end

  describe 'job with secrets' do
    before do
      stub_ci_pipeline_yaml_file <<~YAML
        deploy:
          script:
            - echo
          secrets:
            DATABASE_PASSWORD:
              vault: production/db/password
              token: $ID_TOKEN
      YAML
    end

    it 'persists secrets as job metadata', :aggregate_failures do
      response, pipeline = create_pipeline!

      expect(response).to be_success
      expect(pipeline).to be_persisted

      build = Ci::Build.find(pipeline.builds.first.id)

      expect(build.metadata.secrets).to eq({
        'DATABASE_PASSWORD' => {
          'vault' => {
            'engine' => { 'name' => 'kv-v2', 'path' => 'kv-v2' },
            'path' => 'production/db',
            'field' => 'password'
          },
          'token' => '$ID_TOKEN'
        }
      })
    end
  end

  context 'with partition_id param' do
    let_it_be_with_reload(:user) { project.first_owner }

    let(:ref_name) { 'refs/heads/master' }
    let(:execution_policy_dry_run) { false }

    subject(:execute_service) do
      described_class.new(
        project,
        user,
        source: :push,
        before: '00000000',
        after: project.commit.id,
        ref: ref_name,
        partition_id: ci_testing_partition_id
      ).execute(
        :push,
        save_on_errors: true,
        execution_policy_dry_run: execution_policy_dry_run
      )
    end

    it 'raises error' do
      expect { execute_service }
        .to raise_error(ArgumentError, "Param `partition_id` is only allowed with `execution_policy_dry_run: true`")
    end

    context 'when used with execution_policy_dry_run param' do
      let(:execution_policy_dry_run) { true }

      it 'does not raise an error' do
        expect(execute_service)
          .to be_success
      end
    end
  end

  def create_pipeline!
    response = service.execute(:push)

    [response, response.payload]
  end
end
