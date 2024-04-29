# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Identity Verification', :js, feature_category: :instance_resiliency do
  include IdentityVerificationHelpers
  include ListboxHelpers

  let_it_be_with_reload(:user) { create(:user) }

  before do
    stub_saas_features(identity_verification: true)
    stub_application_setting(
      arkose_labs_public_api_key: 'public_key',
      arkose_labs_private_api_key: 'private_key',
      telesign_customer_xid: 'customer_id',
      telesign_api_key: 'private_key'
    )

    login_as(user)

    visit identity_verification_path
  end

  it 'verifies the user' do
    expect_to_see_identity_verification_page

    verify_phone_number

    expect(page).to have_content(_('Completed'))
    expect(page).to have_content(_('Next'))

    click_link 'Next'

    wait_for_requests

    expect_to_see_dashboard_page
  end

  context 'when the user requests a phone verification exemption' do
    it 'verifies the user' do
      expect_to_see_identity_verification_page

      request_phone_exemption

      verify_credit_card

      expect(page).to have_content(_('Completed'))
      expect(page).to have_content(_('Next'))

      click_link 'Next'

      wait_for_requests

      expect_to_see_dashboard_page
    end
  end
end
