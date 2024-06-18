# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project > Settings > Analytics -> Instrumentation instructions', :js, feature_category: :product_analytics_visualization do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project) { create(:project, namespace: group) }

  before do
    sign_in(user)
  end

  context 'without correct license' do
    before do
      stub_licensed_features(product_analytics: false)

      visit project_settings_analytics_path(project)
    end

    it 'does not show instrumentation instructions' do
      expect(page).not_to have_content s_('View instrumentation instructions')
    end
  end

  context 'when product analytics toggle is disabled' do
    before do
      project.group.root_ancestor.namespace_settings.update!(
        product_analytics_enabled: false
      )
      stub_licensed_features(product_analytics: false)

      visit project_settings_analytics_path(project)
    end

    it 'does not show instrumentation instructions' do
      expect(page).not_to have_content s_('View instrumentation instructions')
    end
  end

  context 'when product analytics is disabled on an instance' do
    before do
      allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(false)
      stub_licensed_features(product_analytics: true)
    end

    it 'does not show instrumentation instructions' do
      expect(page).not_to have_content s_('View instrumentation instructions')
    end
  end

  context 'with valid license, toggle and feature flags' do
    before do
      allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
      stub_licensed_features(product_analytics: true)
    end

    context 'when project is not yet onboarded' do
      let(:project_settings) { { product_analytics_instrumentation_key: nil } }

      before do
        project.project_setting.update!(project_settings)
        project.reload
        visit project_settings_analytics_path(project)
      end

      it 'does not show instrumentation instructions' do
        expect(page).not_to have_content s_('View instrumentation instructions')
      end
    end

    context 'when project is onboarded' do
      let(:instrumentation_key) { 456 }
      let(:collector_host) { 'https://collector.example.com' }

      before do
        stub_application_setting({ product_analytics_data_collector_host: collector_host })
        project.project_setting.update!({ product_analytics_instrumentation_key: instrumentation_key })
        project.reload
        visit project_settings_analytics_path(project)
      end

      it 'shows instrumentation key' do
        fieldset = page.find('fieldset', text: s_('SDK application ID'))
        expect(fieldset.find("input").value).to eq(instrumentation_key.to_s)
      end

      it 'shows collector host' do
        fieldset = page.find('fieldset', text: s_('SDK host'))
        expect(fieldset.find("input").value).to eq(collector_host)
      end

      it 'shows instrumentation setup instructions' do
        expect(page).to have_button(s_("View instrumentation instructions"))

        click_button s_("View instrumentation instructions")

        expect(page).to have_content(
          s_("1. Add the NPM package to your package.json using your preferred package manager"))
        expect(page).to have_content(s_("2. Import the new package into your JS code"))
        expect(page).to have_content(s_("3. Initiate the tracking"))
        expect(page).to have_content(s_("Add the script to the page and assign the client SDK to window"))
      end
    end
  end
end
