# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::PackagesHelper, feature_category: :package_registry do
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:user) { project.creator }

  describe '#settings_data' do
    before do
      allow(helper).to receive(:current_user).and_return(user)
      instance_variable_set(:@project, project)
      allow(Ability).to receive(:allowed?).and_call_original
    end

    subject(:settings_data) { helper.settings_data(project) }

    context 'when the current user cannot admin dependency proxy packages settings' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_dependency_proxy_packages_settings,
          project.dependency_proxy_packages_setting)
          .and_return(false)
      end

      it 'returns the settings data' do
        expect(settings_data).to include(
          show_dependency_proxy_settings: 'false'
        )
      end
    end

    context 'when the current user can admin dependency proxy packages settings' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_dependency_proxy_packages_settings,
          project.dependency_proxy_packages_setting)
          .and_return(true)
      end

      it 'returns the settings data with show_dependency_proxy_settings set to true' do
        expect(settings_data).to include(
          show_dependency_proxy_settings: 'true'
        )
      end
    end
  end

  describe '#google_artifact_registry_data' do
    subject(:data) { helper.google_artifact_registry_data(project) }

    it { is_expected.to include(full_path: project.full_path) }

    describe 'settings_path' do
      before do
        allow(project).to receive(:gcp_artifact_registry_enabled?).and_return(true)
        allow(helper).to receive(:show_container_registry_settings).with(project).and_return(true)
      end

      it do
        is_expected.to include(settings_path: edit_project_settings_integration_path(project,
          ::Integrations::GoogleCloudPlatform::ArtifactRegistry))
      end

      context 'when gcp_artifact_registry_enabled? is false' do
        before do
          allow(project).to receive(:gcp_artifact_registry_enabled?).and_return(false)
        end

        it { is_expected.to include(settings_path: '') }
      end

      context 'when show_container_registry_settings is false' do
        before do
          allow(helper).to receive(:show_container_registry_settings).with(project).and_return(false)
        end

        it { is_expected.to include(settings_path: '') }
      end
    end
  end
end
