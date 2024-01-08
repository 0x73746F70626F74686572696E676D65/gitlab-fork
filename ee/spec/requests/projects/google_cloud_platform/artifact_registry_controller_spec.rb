# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GoogleCloudPlatform::ArtifactRegistryController, feature_category: :container_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }

  before do
    sign_in(user)
    stub_container_registry_config(enabled: true)
    stub_saas_features(google_artifact_registry: true)
  end

  describe 'GET #index' do
    subject do
      get project_google_cloud_platform_artifact_registry_index_path(project)
    end

    context 'when user has access to registry' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'returning response status', :ok

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(gcp_artifact_registry: false)
        end

        it_behaves_like 'returning response status', :not_found
      end

      context 'when feature is unavailable' do
        before do
          stub_saas_features(google_artifact_registry: false)
        end

        it_behaves_like 'returning response status', :not_found
      end
    end

    context 'when user does not have access to registry' do
      it_behaves_like 'returning response status', :not_found
    end
  end
end
