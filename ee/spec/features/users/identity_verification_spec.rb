# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Identity Verification', :js, feature_category: :instance_resiliency do
  include IdentityVerificationHelpers
  include ListboxHelpers

  let_it_be_with_reload(:user) do
    create(:user, :identity_verification_eligible)
  end

  let(:require_iv_for_old_users) { false }

  before do
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?)
      .with(:phone_verification_send_code, scope: user).and_return(false)

    stub_feature_flags(require_identity_verification_for_old_users: require_iv_for_old_users)
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

  shared_examples 'verifies the user' do
    specify do
      expect_to_see_identity_verification_page

      verify_phone_number(solve_arkose_challenge: true)

      expect(page).to have_content(_('Completed'))
      expect(page).to have_content(_('Next'))

      click_link 'Next'

      wait_for_requests

      expect_to_see_dashboard_page
    end
  end

  it_behaves_like 'verifies the user'

  context 'when the user was created before the feature relase date' do
    let_it_be(:user) do
      create(:user, created_at: IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE - 1.day)
    end

    context 'when identity verification is required for old users' do
      let(:require_iv_for_old_users) { true }

      it_behaves_like 'verifies the user'
    end

    context 'when identity verification is not required for old users' do
      it 'does not verify the user' do
        expect_to_see_dashboard_page
      end
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

  context 'when the user gets a high risk score from Telesign' do
    it 'inserts credit card verification requirement before phone number' do
      expect_to_see_identity_verification_page

      expect(page).to have_content('Step 1: Verify phone number')

      send_phone_number_verification_code(
        solve_arkose_challenge: true,
        telesign_opts: { risk_score: ::IdentityVerification::UserRiskProfile::TELESIGN_HIGH_RISK_THRESHOLD + 1 }
      )

      expect(page).to have_content('Step 1: Verify a payment method')

      verify_credit_card

      expect(page).to have_content(_('Completed'))

      verify_phone_number

      click_link 'Next'

      wait_for_requests

      expect_to_see_dashboard_page
    end
  end
end
