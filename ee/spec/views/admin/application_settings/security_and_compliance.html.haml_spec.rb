# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/security_and_compliance.html.haml', feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { build_stubbed(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  subject { rendered }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)

    stub_licensed_features(pre_receive_secret_detection: feature_available)
  end

  shared_examples 'renders pre receive secret detection setting' do
    it do
      render

      expect(rendered).to have_css('[data-testid="admin-secret-detection-settings"]')
    end
  end

  shared_examples 'does not render pre receive secret detection setting' do
    it do
      render

      expect(rendered).not_to have_css('[data-testid="admin-secret-detection-settings"]')
    end
  end

  context 'when instance is dedicated' do
    before do
      stub_application_setting(gitlab_dedicated_instance: true)
    end

    describe 'feature available' do
      let(:feature_available) { true }

      it_behaves_like 'renders pre receive secret detection setting'
    end

    describe 'feature not available' do
      let(:feature_available) { false }

      it_behaves_like 'does not render pre receive secret detection setting'
    end
  end

  context 'when instance is not dedicated but feature flag is enabled' do
    before do
      stub_feature_flags(pre_receive_secret_detection_beta_release: true)
    end

    let(:feature_available) { true }

    describe 'feature available' do
      it_behaves_like 'renders pre receive secret detection setting'
    end
  end

  context 'when instance is not dedicated and feature flag is disabled' do
    before do
      stub_feature_flags(pre_receive_secret_detection_beta_release: false)
    end

    let(:feature_available) { true }

    describe 'feature available' do
      it_behaves_like 'does not render pre receive secret detection setting'
    end
  end
end
