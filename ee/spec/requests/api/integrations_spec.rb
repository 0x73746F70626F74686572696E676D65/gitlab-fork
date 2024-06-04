# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Integrations, feature_category: :integrations do
  include Integrations::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, namespace: user.namespace) }
  let_it_be(:project2) { create(:project, creator_id: user.id, namespace: user.namespace) }

  let_it_be(:available_integration_names) do
    Integration::EE_PROJECT_SPECIFIC_INTEGRATION_NAMES.union(Integration::GOOGLE_CLOUD_PLATFORM_INTEGRATION_NAMES)
  end

  let_it_be(:project_integrations_map) do
    available_integration_names.index_with do |name|
      create(integration_factory(name), :inactive, project: project)
    end
  end

  before do
    stub_saas_features(google_cloud_support: true)
  end

  shared_examples 'handling google artifact registry conditions' do |unavailable_status: :not_found|
    shared_examples 'does not change integrations count' do
      it do
        expect { subject }.not_to change { project.integrations.count }
      end
    end

    context 'when google artifact registry feature is unavailable' do
      before do
        stub_saas_features(google_cloud_support: false)
      end

      it_behaves_like 'returning response status', unavailable_status
      it_behaves_like 'does not change integrations count'
    end
  end

  %w[integrations services].each do |endpoint|
    where(:integration) do
      Integration::EE_PROJECT_SPECIFIC_INTEGRATION_NAMES.union(Integration::GOOGLE_CLOUD_PLATFORM_INTEGRATION_NAMES)
    end

    with_them do
      integration = params[:integration]

      describe "PUT /projects/:id/#{endpoint}/#{integration.dasherize}" do
        it_behaves_like 'set up an integration', endpoint: endpoint, integration: integration
      end

      describe "DELETE /projects/:id/#{endpoint}/#{integration.dasherize}" do
        it_behaves_like 'disable an integration', endpoint: endpoint, integration: integration
      end

      describe "GET /projects/:id/#{endpoint}/#{integration.dasherize}" do
        it_behaves_like 'get an integration settings', endpoint: endpoint, integration: integration
      end
    end

    describe 'GitGuardian Integration' do
      let(:integration_name) { 'git-guardian' }

      context 'when git_guardian_integration feature flag is disabled' do
        before do
          stub_feature_flags(git_guardian_integration: false)
        end

        it 'returns 400  for put request' do
          put api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user), params: { token: 'api-token' }
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to eq("{\"message\":\"GitGuardian feature is disabled\"}")
        end

        it 'returns 400  for delete request' do
          delete api("/projects/#{project.id}/#{endpoint}/#{integration_name}", user)
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to eq("{\"message\":\"GitGuardian feature is disabled\"}")
        end
      end
    end
  end

  describe 'Google Artifact Registry' do
    shared_examples 'handling google artifact registry conditions' do |unavailable_status: :not_found|
      shared_examples 'does not change integrations count' do
        it do
          expect { subject }.not_to change { project.integrations.count }
        end
      end

      context 'when google artifact registry feature is unavailable' do
        before do
          stub_saas_features(google_cloud_support: false)
        end

        it_behaves_like 'returning response status', unavailable_status
        it_behaves_like 'does not change integrations count'
      end
    end

    describe 'PUT /projects/:id/integrations/google-cloud-platform-artifact-registry' do
      let(:params) do
        {
          workload_identity_pool_project_number: '917659427920',
          workload_identity_pool_id: 'gitlab-gcp-demo',
          workload_identity_pool_provider_id: 'gitlab-gcp-prod-gitlab-org',
          artifact_registry_project_id: 'dev-gcp-9abafed1',
          artifact_registry_location: 'us-east1',
          artifact_registry_repositories: 'demo'
        }
      end

      let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-artifact-registry", user) }

      it_behaves_like 'handling google artifact registry conditions', unavailable_status: :bad_request do
        subject { put url, params: params }
      end
    end

    describe 'DELETE /projects/:id/integrations/google-cloud-platform-artifact-registry' do
      let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-artifact-registry", user) }

      before do
        project_integrations_map['google_cloud_platform_artifact_registry'].activate!
      end

      it_behaves_like 'handling google artifact registry conditions' do
        subject { delete url }
      end
    end

    describe 'GET /projects/:id/integrations/google-cloud-platform-artifact-registry' do
      let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-artifact-registry", user) }

      before do
        project_integrations_map['google_cloud_platform_artifact_registry'].activate!
      end

      it_behaves_like 'handling google artifact registry conditions' do
        subject { get url }
      end
    end
  end

  context 'when Google Cloud Workload Identity Federation integration feature is unavailable' do
    let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-workload-identity-federation", user) }

    before do
      project_integrations_map['google_cloud_platform_workload_identity_federation'].activate!
      stub_saas_features(google_cloud_support: false)
    end

    describe 'GET /projects/:id/integrations/google-cloud-workload-identity-federation' do
      it_behaves_like 'returning response status', :not_found do
        subject { get url }
      end
    end

    describe 'PUT /projects/:id/integrations/google-cloud-workload-identity-federation' do
      let(:params) do
        {
          workload_identity_federation_project_id: 'google-wlif-project-id',
          workload_identity_federation_project_number: '123456789',
          workload_identity_pool_id: 'wlif-pool-id',
          workload_identity_pool_provider_id: 'wlif-pool-provider-id'
        }
      end

      it_behaves_like 'returning response status', :bad_request do
        subject { put url, params: params }
      end
    end

    describe 'DELETE /projects/:id/integrations/google-cloud-workload-identity-federation' do
      it_behaves_like 'returning response status', :not_found do
        subject { delete url }
      end
    end
  end
end
