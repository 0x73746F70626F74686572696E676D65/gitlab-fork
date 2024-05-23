# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Identity Verification', :js, feature_category: :instance_resiliency do
  include IdentityVerificationHelpers

  before do
    stub_saas_features(identity_verification: true)
    stub_application_setting_enum('email_confirmation_setting', 'hard')
    stub_application_setting(
      require_admin_approval_after_user_signup: false,
      arkose_labs_public_api_key: 'public_key',
      arkose_labs_private_api_key: 'private_key',
      telesign_customer_xid: 'customer_id',
      telesign_api_key: 'private_key'
    )

    stub_request(:get, "https://status.arkoselabs.com/api/v2/status.json")
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        })
      .to_return(
        status: 200,
        body: { status: { indicator: arkose_status_indicator } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  let(:user_email) { 'onboardinguser@example.com' }
  let(:new_user) { build(:user, email: user_email) }
  let(:user) { User.find_by_email(user_email) }
  let(:arkose_status_indicator) { 'none' }

  shared_examples 'does not allow unauthorized access to verification endpoints' do |protected_endpoints|
    # Normally, users cannot trigger requests to endpoints of verification
    # methods in later steps by only using the UI (e.g. if the current step is
    # email verification. Phone and credit card steps cannot be interacted
    # with). However, there is nothing stopping users from manually or
    # programatically sending requests to these endpoints.
    #
    # This spec ensures that only the endpoints of the verification method in
    # the current step are accessible to the user regardless of the way the
    # request is sent.
    #
    # Note: SAML flow is skipped as the signin process is more involved which
    # makes the test unnecessarily complex.

    def send_request(session, method, path, headers:)
      session.public_send(method, path, headers: headers, xhr: true, as: :json)
    end

    it do
      session = ActionDispatch::Integration::Session.new(Rails.application)

      # sign in
      session.post user_session_path, params: { user: { login: new_user.username, password: new_user.password } }

      # visit identity verification page
      session.get signup_identity_verification_path

      # extract CSRF token
      body = session.response.body
      html = Nokogiri::HTML.parse(body)
      csrf_token = html.at("meta[name=csrf-token]")['content']

      headers = { 'X-CSRF-Token' => csrf_token }

      phone_send_code_path = send_phone_verification_code_signup_identity_verification_path
      phone_verify_code_path = verify_phone_verification_code_signup_identity_verification_path
      credit_card_verify_path = verify_credit_card_signup_identity_verification_path

      verification_endpoint_requests = {
        phone: [
          -> { send_request(session, :post, phone_send_code_path, headers: headers) },
          -> { send_request(session, :post, phone_verify_code_path, headers: headers) }
        ],
        credit_card: [
          -> { send_request(session, :get, credit_card_verify_path, headers: {}) }
        ]
      }

      protected_endpoints.each do |e|
        verification_endpoint_requests[e].each do |request_lambda|
          expect(request_lambda.call).to eq 400
        end
      end
    end
  end

  shared_examples 'registering a low risk user with identity verification' do |flow: :others|
    let(:risk) { :low }

    it 'verifies the user' do
      expect_to_see_identity_verification_page

      verify_email

      expect_verification_completed

      expect_to_see_dashboard_page
    end

    context 'when the verification code is empty' do
      it 'shows error message' do
        verify_code('')

        expect(page).to have_content(s_('IdentityVerification|Enter a code.'))
      end
    end

    context 'when the verification code is invalid' do
      it 'shows error message' do
        verify_code('xxx')

        expect(page).to have_content(s_('IdentityVerification|Enter a valid code.'))
      end
    end

    context 'when the verification code has expired' do
      before do
        travel (Users::EmailVerification::ValidateTokenService::TOKEN_VALID_FOR_MINUTES + 1).minutes
      end

      it 'shows error message' do
        verify_code(email_verification_code)

        expect(page).to have_content(s_('IdentityVerification|The code has expired. Send a new code and try again.'))
      end
    end

    context 'when the verification code is incorrect' do
      it 'shows error message' do
        verify_code('000000')

        expect(page).to have_content(
          s_('IdentityVerification|The code is incorrect. Enter it again, or send a new code.')
        )
      end
    end

    context 'when user requests a new code' do
      it 'resends a new code' do
        click_link 'Send a new code'

        expect(page).to have_content(s_('IdentityVerification|A new code has been sent.'))
      end
    end

    unless flow == :saml
      describe 'access to verification endpoints' do
        it_behaves_like 'does not allow unauthorized access to verification endpoints', [:phone, :credit_card]
      end
    end
  end

  shared_examples 'registering a medium risk user with identity verification' do
    |skip_email_validation: false, flow: :others|

    let(:risk) { :medium }

    it 'verifies the user' do
      expect_to_see_identity_verification_page

      verify_email unless skip_email_validation

      verify_phone_number(solve_arkose_challenge: true)

      expect_verification_completed

      expect_to_see_dashboard_page
    end

    context 'when the user requests a phone verification exemption' do
      it 'verifies the user' do
        expect_to_see_identity_verification_page

        verify_email unless skip_email_validation

        request_phone_exemption

        solve_arkose_verify_challenge

        verify_credit_card

        # verify_credit_card creates a credit_card verification record &
        # refreshes the page. This causes an automatic redirect to the welcome
        # page, skipping the verification successful badge, and preventing us
        # from calling expect_verification_completed

        expect_to_see_dashboard_page
      end
    end

    unless flow == :saml
      describe 'access to verification endpoints' do
        it_behaves_like 'does not allow unauthorized access to verification endpoints', [:credit_card]

        context 'when all prerequisite verification methods have not been completed' do
          unless skip_email_validation
            it_behaves_like 'does not allow unauthorized access to verification endpoints', [:phone]
          end
        end
      end
    end
  end

  shared_examples 'registering a high risk user with identity verification' do
    |skip_email_validation: false, flow: :others|

    let(:risk) { :high }

    it 'verifies the user' do
      expect_to_see_identity_verification_page

      verify_email unless skip_email_validation

      verify_phone_number(solve_arkose_challenge: true)

      verify_credit_card

      expect_to_see_dashboard_page
    end

    context 'and the user has a phone verification exemption' do
      it 'verifies the user' do
        user.create_phone_number_exemption!

        expect_to_see_identity_verification_page

        verify_email unless skip_email_validation

        solve_arkose_verify_challenge

        verify_credit_card

        # verify_credit_card creates a credit_card verification record &
        # refreshes the page. This causes an automatic redirect to the welcome
        # page, skipping the verification successful badge, and preventing us
        # from calling expect_verification_completed

        expect_to_see_dashboard_page
      end
    end

    unless flow == :saml
      describe 'access to verification endpoints' do
        context 'when all prerequisite verification methods have been completed' do
          before do
            verify_email unless skip_email_validation

            solve_arkose_verify_challenge

            verify_phone_number(solve_arkose_challenge: true)
          end

          it_behaves_like 'does not allow unauthorized access to verification endpoints', [:phone]
        end

        context 'when some prerequisite verification methods have not been completed' do
          before do
            verify_email unless skip_email_validation
          end

          it_behaves_like 'does not allow unauthorized access to verification endpoints', [:credit_card]
        end

        context 'when all prerequisite verification methods have not been completed' do
          it_behaves_like 'does not allow unauthorized access to verification endpoints', [:credit_card]
        end
      end
    end
  end

  shared_examples 'allows the user to complete registration when Arkose is down' do
    let(:risk) { nil }
    let(:arkose_token_verification_response) { { error: "DENIED ACCESS" } }
    let(:arkose_status_indicator) { 'critical' }

    it 'allows the user to complete the registration' do
      expect_to_see_identity_verification_page

      verify_email

      expect_verification_completed

      expect_to_see_dashboard_page
    end
  end

  describe 'Standard flow' do
    before do
      visit new_user_registration_path
    end

    context 'when Arkose is up' do
      before do
        sign_up
      end

      it_behaves_like 'registering a low risk user with identity verification'
      it_behaves_like 'registering a medium risk user with identity verification'
      it_behaves_like 'registering a high risk user with identity verification'
    end

    it_behaves_like 'allows the user to complete registration when Arkose is down' do
      before do
        sign_up(arkose_verify_response: arkose_token_verification_response)
      end
    end
  end

  describe 'Invite flow' do
    let(:invitation) { create(:group_member, :invited, :developer, invite_email: user_email) }

    before do
      visit invite_path(invitation.raw_invite_token, invite_type: Emails::Members::INITIAL_INVITE)
    end

    context 'when Arkose is up' do
      before do
        sign_up(invite: true)
      end

      context 'when the user is low risk' do
        let(:risk) { :low }

        it 'does not verify the user and lands on group page' do
          expect(page).to have_current_path(group_path(invitation.group))
          expect(page).to have_content(
            "You have been granted access to the #{invitation.group.name} group with the following role: Developer."
          )
        end
      end

      it_behaves_like 'registering a medium risk user with identity verification', skip_email_validation: true
      it_behaves_like 'registering a high risk user with identity verification', skip_email_validation: true
    end

    context 'when Arkose is down' do
      let(:risk) { nil }
      let(:arkose_token_verification_response) { { error: "DENIED ACCESS" } }
      let(:arkose_status_indicator) { 'critical' }

      before do
        sign_up(invite: true, arkose_verify_response: arkose_token_verification_response)
      end

      it 'allows the user to complete registration' do
        expect(page).to have_current_path(group_path(invitation.group))
        expect(page).to have_content(
          "You have been granted access to the #{invitation.group.name} group with the following role: Developer."
        )
      end
    end
  end

  describe 'Trial flow', :saas do
    before do
      visit new_trial_registration_path
    end

    context 'when Arkose is up' do
      before do
        trial_sign_up
      end

      it_behaves_like 'registering a low risk user with identity verification'
      it_behaves_like 'registering a medium risk user with identity verification'
      it_behaves_like 'registering a high risk user with identity verification'
    end

    it_behaves_like 'allows the user to complete registration when Arkose is down' do
      before do
        trial_sign_up(arkose_verify_response: arkose_token_verification_response)
      end
    end
  end

  describe 'SAML flow' do
    let(:provider) { 'google_oauth2' }

    before do
      stub_arkose_token_verification(response: arkose_token_verification_response)

      mock_auth_hash(provider, 'external_uid', user_email)
      stub_omniauth_setting(block_auto_created_users: false)

      visit new_user_registration_path
      saml_sign_up
    end

    around do |example|
      with_omniauth_full_host { example.run }
    end

    context 'when Arkose is up' do
      let(:arkose_token_verification_response) { { session_risk: { risk_band: risk.capitalize } } }

      it_behaves_like 'registering a low risk user with identity verification', flow: :saml
      it_behaves_like 'registering a medium risk user with identity verification', flow: :saml
      it_behaves_like 'registering a high risk user with identity verification', flow: :saml
    end

    it_behaves_like 'allows the user to complete registration when Arkose is down'
  end

  describe 'Subscription flow', :saas do
    before do
      stub_ee_application_setting(should_check_namespace_plan: true)

      visit new_subscriptions_path
    end

    context 'when Arkose is up' do
      before do
        sign_up
      end

      it_behaves_like 'registering a low risk user with identity verification'
      it_behaves_like 'registering a medium risk user with identity verification'
      it_behaves_like 'registering a high risk user with identity verification'
    end

    it_behaves_like 'allows the user to complete registration when Arkose is down' do
      before do
        sign_up(arkose_verify_response: arkose_token_verification_response)
      end
    end
  end

  describe 'user that already went through identity verification' do
    context 'when the user is medium risk but phone verification feature-flag is turned off' do
      let(:risk) { :medium }

      before do
        stub_feature_flags(identity_verification_phone_number: false)

        visit new_user_registration_path
        sign_up
      end

      it 'verifies the user with email only' do
        expect_to_see_identity_verification_page

        verify_email

        expect_verification_completed

        expect_to_see_dashboard_page

        user_signs_out

        # even though the phone verification feature-flag is turned back on
        # when the user logs in next, they will not be asked to do identity verification again
        stub_feature_flags(identity_verification_phone_number: true)

        gitlab_sign_in(user, password: new_user.password)

        expect_to_see_dashboard_page
      end
    end
  end

  private

  def sign_up(invite: false, arkose_verify_response: {})
    fill_in_sign_up_form(new_user, invite: invite) do
      solve_arkose_verify_challenge(risk: risk, response: arkose_verify_response)
    end
  end

  def saml_sign_up
    click_button Gitlab::Auth::OAuth::Provider.label_for(provider)
  end

  def trial_sign_up(arkose_verify_response: {})
    fill_in_sign_up_form(new_user, 'Continue') do
      solve_arkose_verify_challenge(risk: risk, response: arkose_verify_response)
    end
  end

  def user_signs_out
    find_by_testid('user-dropdown').click
    click_link 'Sign out'

    expect(page).to have_button(_('Sign in'))
  end
end
