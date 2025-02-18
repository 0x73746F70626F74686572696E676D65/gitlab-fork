# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/registrations/new', feature_category: :system_access do
  let(:arkose_labs_enabled) { true }
  let(:arkose_labs_api_key) { "api-key" }
  let(:arkose_labs_domain) { "domain" }

  subject { render(template: 'devise/registrations/new') }

  before do
    stub_devise

    allow(view).to receive(:glm_tracking_params).and_return({})
    allow(view).to receive(:arkose_labs_enabled?).and_return(arkose_labs_enabled)
    allow(view).to receive(:preregistration_tracking_label).and_return('free_registration')
    allow(::Arkose::Settings).to receive(:arkose_public_api_key).and_return(arkose_labs_api_key)
    allow(::Arkose::Settings).to receive(:arkose_labs_domain).and_return(arkose_labs_domain)
  end

  it 'renders challenge container with the correct data attributes', :aggregate_failures do
    subject

    expect(rendered).to have_selector('#js-arkose-labs-challenge')
    expect(rendered).to have_selector("[data-api-key='#{arkose_labs_api_key}']")
    expect(rendered).to have_selector("[data-domain='#{arkose_labs_domain}']")
  end

  context 'when the feature is disabled' do
    let(:arkose_labs_enabled) { false }

    it 'does not render challenge container', :aggregate_failures do
      subject

      expect(rendered).not_to have_selector('#js-arkose-labs-challenge')
      expect(rendered).not_to have_selector("[data-api-key='#{arkose_labs_api_key}']")
      expect(rendered).not_to have_selector("[data-domain='#{arkose_labs_domain}']")
    end
  end

  describe 'broadcast messaging' do
    before do
      stub_ee_application_setting(should_check_namespace_plan: should_check_namespace_plan)
      stub_devise

      allow(view).to receive(:glm_tracking_params).and_return({})
      allow(view).to receive(:arkose_labs_enabled?).and_return(arkose_labs_enabled)

      render
    end

    context 'when self-hosted' do
      let(:should_check_namespace_plan) { false }

      it { expect(rendered).not_to render_template('layouts/_broadcast') }
    end

    context 'when SaaS' do
      let(:should_check_namespace_plan) { true }

      it { expect(rendered).not_to render_template('layouts/_broadcast') }
    end
  end

  def stub_devise
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:resource).and_return(build(:user))
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:registration_path_params).and_return({})
  end
end
