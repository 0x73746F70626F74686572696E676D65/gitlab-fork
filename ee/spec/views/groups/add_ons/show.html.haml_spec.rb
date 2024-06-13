# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "groups/add_ons/discover_duo_pro/show", :aggregate_failures, feature_category: :onboarding do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
    render
  end

  it 'renders the discover duo page' do
    expect(rendered).to have_text(
      s_(
        'DuoProDiscover|Ship software faster and more securely with AI integrated into your entire DevSecOps lifecycle.'
      )
    )
    expect(rendered).to include `data-src="/assets/duo_pro/duo-logo`
    expect(rendered).to include `data-src="/assets/duo_pro/duo-video-thumbnail`
  end

  context 'with tracking' do
    it 'has tracking for the buy now button' do
      expect_to_have_tracking(action: 'click_buy_now', label: 'duo_pro_active_trial')
    end

    it 'has tracking for the contact sales button' do
      expect_to_have_tracking(action: 'click_contact_sales', label: 'duo_pro_active_trial')
    end
  end

  def expect_to_have_tracking(action:, label:)
    css = `data-cta-tracking={"action": #{action}, "label": #{label}}`

    expect(rendered).to include(css)
  end
end
