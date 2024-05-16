# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettingsController, :enable_admin_mode, feature_category: :shared do
  include StubENV

  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
  end

  describe 'PUT update_microsoft_application', feature_category: :system_access do
    it_behaves_like 'Microsoft application controller actions' do
      let(:path) { update_microsoft_application_admin_application_settings_path }

      before do
        allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
      end
    end
  end

  describe 'GET #general', feature_category: :user_management do
    context 'with feature flag :disallow_private_profiles disabled' do
      before do
        stub_feature_flags(disallow_private_profiles: false)
      end

      it 'does not push :disable_private_profiles license feature' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:push_licensed_feature).with(:password_complexity)
          expect(instance).not_to receive(:push_licensed_feature).with(:disable_private_profiles)
        end

        get general_admin_application_settings_path
      end
    end

    it 'does push :disable_private_profiles license feature' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:push_licensed_feature).with(:password_complexity)
        expect(instance).to receive(:push_licensed_feature).with(:disable_private_profiles)
      end

      get general_admin_application_settings_path
    end
  end
end
