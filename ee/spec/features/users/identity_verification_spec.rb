# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Identity Verification', :js, feature_category: :instance_resiliency do
  include IdentityVerificationHelpers
  include ListboxHelpers

  let_it_be_with_reload(:user) do
    create(:user, created_at: IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE + 1.day)
  end

  let(:require_challenge) { true }

  before do
    stub_feature_flags(identity_verification_arkose_challenge: require_challenge)
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

    verify_phone_number(solve_arkose_challenge: true)

    expect(page).to have_content(_('Completed'))
    expect(page).to have_content(_('Next'))

    click_link 'Next'

    wait_for_requests

    expect_to_see_dashboard_page
  end

  context 'when the user was created before the feature relase date' do
    let_it_be(:user) do
      create(:user, created_at: IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE - 1.day)
    end

    it 'does not verify the user' do
      expect_to_see_dashboard_page
    end
  end

  context 'when identity_verification_arkose_challenge is disabled' do
    let(:require_challenge) { false }

    it 'does not require the user to solve an Arkose challenge' do
      verify_phone_number

      expect(page).to have_content(_('Completed'))
    end
  end

  context 'when the user requests a phone verification exemption' do
    it 'verifies the user' do
      expect_to_see_identity_verification_page

      request_phone_exemption

      solve_arkose_verify_challenge

      verify_credit_card

      # verify_credit_card creates a credit_card verification record & refreshes
      # the page. This causes an automatic redirect to the root_path because the
      # user is already identity verified

      expect_to_see_dashboard_page
    end
  end
end
