# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Ci::RetryPipelineService, feature_category: :continuous_integration do
  let_it_be(:runner) { create(:ci_runner, :instance, :online) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:service) { described_class.new(project, user) }

  before do
    project.add_developer(user)

    create(:protected_branch, :developers_can_merge, name: pipeline.ref, project: project)
  end

  context 'when the namespace is out of compute minutes' do
    let_it_be(:namespace) { create(:namespace, :with_used_build_minutes_limit) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:private_runner) do
      create(:ci_runner, :project, :online, projects: [project], tag_list: ['ruby'], run_untagged: false)
    end

    before do
      create_build('rspec 1', :failed)
      create_build('rspec 2', :canceled, tag_list: ['ruby'])
    end

    it 'retries the builds with available runners' do
      service.execute(pipeline)

      expect(pipeline.statuses.count).to eq(3)
      expect(build('rspec 1')).to be_failed
      expect(build('rspec 2')).to be_pending
      expect(pipeline.reload).to be_running
    end
  end

  context 'when the user is not authorized to run jobs' do
    before do
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:authorize_run_jobs!)
          .and_raise(::Users::IdentityVerification::Error, 'authorization error')
      end
    end

    it 'returns an error' do
      response = service.execute(pipeline)

      expect(response.http_status).to eq(:forbidden)
      expect(response.errors).to include('authorization error')
      expect(pipeline.reload).not_to be_running
    end
  end

  context 'when secrets provider not found check fails' do
    before do
      stub_licensed_features(ci_secrets_management: true)
    end

    let!(:build) { create(:ci_build, status: :created, pipeline: pipeline) }

    it 'gracefully fails pipeline' do
      allow_next_found_instance_of(::Ci::Build) do |build|
        allow(build)
          .to receive(:secrets?)
          .and_return(true)
        allow(build)
          .to receive(:secrets_provider?)
          .and_return(false)
      end

      response = service.execute(pipeline)

      expect(response.http_status).to eq(:ok)
      expect(pipeline.reload).to be_failed
      expect(build.reload).to be_failed
    end
  end

  def build(name)
    pipeline.reload.statuses.latest.find_by(name: name)
  end

  def create_build(name, status, **opts)
    create(:ci_build, name: name, status: status, pipeline: pipeline, **opts) do |build|
      ::Ci::ProcessPipelineService.new(pipeline).execute
    end
  end
end
