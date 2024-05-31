# frozen_string_literal: true

require 'support/helpers/listbox_helpers'

module IdentityVerificationHelpers
  include ListboxHelpers

  def stub_arkose_token_verification(
    risk: :low, token_verification_response: :success, challenge_shown: false, service_down: false
  )

    success_response = {
      session_risk: { risk_band: risk.capitalize },
      session_details: { suppressed: !challenge_shown }
    }

    error_response = { error: "DENIED ACCESS" }
    return_error = token_verification_response == :failed

    stub_request(:post, 'https://verify-api.arkoselabs.com/api/v4/verify/')
    .to_return(
      status: 200,
      body: return_error ? error_response.to_json : success_response.to_json,
      headers: { content_type: 'application/json' }
    )

    status_indicator = service_down ? 'critical' : 'none'

    stub_request(:get, "https://status.arkoselabs.com/api/v2/status.json")
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Ruby'
        })
      .to_return(
        status: 200,
        body: { status: { indicator: status_indicator } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def solve_arkose_verify_challenge(**opts)
    stub_arkose_token_verification(**opts)

    selector = '[data-testid="arkose-labs-token-input"]'
    page.execute_script("document.querySelector('#{selector}').value='mock_arkose_labs_session_token'")
    page.execute_script("document.querySelector('#{selector}').dispatchEvent(new Event('input'))")
  end

  def stub_telesign_verification(risk_score: ::IdentityVerification::UserRiskProfile::TELESIGN_HIGH_RISK_THRESHOLD)
    allow_next_instance_of(::PhoneVerification::TelesignClient::RiskScoreService) do |service|
      allow(service).to receive(:execute).and_return(
        ServiceResponse.success(payload: { risk_score: risk_score })
      )
    end

    allow_next_instance_of(::PhoneVerification::TelesignClient::SendVerificationCodeService) do |service|
      allow(service).to receive(:execute).and_return(
        ServiceResponse.success(payload: { telesign_reference_xid: '123' })
      )
    end

    allow_next_instance_of(::PhoneVerification::TelesignClient::VerifyCodeService) do |service|
      allow(service).to receive(:execute).and_return(
        ServiceResponse.success(payload: { telesign_reference_xid: '123' })
      )
    end
  end

  def email_verification_code
    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.find { |d| d.to.include?(user_email) }
    expect(mail.subject).to eq('Confirm your email address')

    mail.body.parts.first.to_s[/\d{#{Users::EmailVerification::GenerateTokenService::TOKEN_LENGTH}}/o]
  end

  def verify_email
    content = format(
      "We've sent a verification code to %{email}",
      email: Gitlab::Utils::Email.obfuscated_email(user_email)
    )
    expect(page).to have_content(content)

    fill_in 'verification_code', with: email_verification_code
    click_button s_('IdentityVerification|Verify email address')

    expect(page).to have_content(_('Completed'))
  end

  def send_phone_number_verification_code(solve_arkose_challenge: false, arkose_opts: {}, telesign_opts: {})
    expect(page).to have_content('Send code')

    solve_arkose_verify_challenge(**arkose_opts) if solve_arkose_challenge

    stub_telesign_verification(**telesign_opts)

    us_list_item = '🇺🇸 United States of America (+1)'
    au_list_item = '🇦🇺 Australia (+61)'
    select_from_listbox(au_list_item, from: us_list_item) if has_content?(us_list_item)

    fill_in 'phone_number', with: '400000000'
    click_button s_('IdentityVerification|Send code')
  end

  def verify_phone_number(solve_arkose_challenge: false, **opts)
    send_phone_number_verification_code(solve_arkose_challenge: solve_arkose_challenge, **opts)

    content = format(
      s_("IdentityVerification|We've sent a verification code to +%{phoneNumber}"),
      phoneNumber: '61400000000'
    )

    expect(page).to have_content(content)

    mock_verification_code = '4319315'
    fill_in 'verification_code', with: mock_verification_code

    click_button s_('IdentityVerification|Verify phone number')
  end

  def request_phone_exemption
    click_button s_('IdentityVerification|Verify with a credit card instead?')
  end

  def verify_credit_card
    # It's too hard to simulate an actual credit card validation, since it relies on loading an external script,
    # rendering external content in an iframe and several API calls to the subscription portal from the backend.
    # So instead we create a credit_card_validation directly and reload the page here.
    create(:credit_card_validation, user: user)
    visit current_path
  end

  def confirmation_code
    mail = find_email_for(user)
    expect(mail.to).to match_array([user.email])
    expect(mail.subject).to eq(s_('IdentityVerification|Confirm your email address'))
    code = mail.body.parts.first.to_s[/\d{#{Users::EmailVerification::GenerateTokenService::TOKEN_LENGTH}}/o]
    reset_delivered_emails!
    code
  end

  def verify_code(code)
    fill_in 'verification_code', with: code
    click_button s_('IdentityVerification|Verify email address')
  end

  def expect_to_see_identity_verification_page
    expect(page).to have_content(
      s_("IdentityVerification|For added security, you'll need to verify your identity")
    )
  end

  def expect_verification_completed
    expect(page).to have_content(_('Completed'))
    expect(page).to have_content(_('Next'))

    click_link 'Next'

    wait_for_requests

    expect(page).to have_current_path(success_signup_identity_verification_path)
    expect(page).to have_content(s_('IdentityVerification|Verification successful'))
  end

  def expect_to_see_dashboard_page
    expect(page).to have_content(_('Welcome to GitLab'))
  end
end
