# frozen_string_literal: true

def mock_arkose_token_verification(success:, service_down: false)
  allow(::Arkose::Settings).to receive(:enabled?).and_return(true)

  success_response = ServiceResponse.success(
    payload: {
      response:
        Arkose::VerifyResponse.new(
          Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response.json')))
        )
    })
  failed_response = ServiceResponse.error(message: "DENIED ACCESS")

  allow_next_instance_of(Arkose::TokenVerificationService) do |instance|
    verification_response = success ? success_response : failed_response
    allow(instance).to receive(:execute).and_return(verification_response)
  end

  allow_next_instance_of(::Arkose::StatusService) do |instance|
    status_response = service_down ? ServiceResponse.error(message: 'Arkose outage') : ServiceResponse.success
    allow(instance).to receive(:execute).and_return(status_response)
  end
end

def mock_send_phone_number_verification_code(success:, response_opts: {})
  response = success ? ServiceResponse.success(**response_opts) : ServiceResponse.error(**response_opts)
  allow_next_instance_of(::PhoneVerification::Users::SendVerificationCodeService) do |service|
    allow(service).to receive(:execute).and_return(response)
  end
end

def mock_verify_phone_number_verification_code(success:, response_opts: {})
  response = success ? ServiceResponse.success(**response_opts) : ServiceResponse.error(**response_opts)
  allow_next_instance_of(::PhoneVerification::Users::VerifyCodeService) do |service|
    allow(service).to receive(:execute).and_return(response)
  end
end

def mock_rate_limit(limit_name, method, result, scope: nil)
  allow(::Gitlab::ApplicationRateLimiter).to receive(method).with(limit_name, scope: scope).and_return(result)
end

RSpec.shared_examples 'logs and tracks the event' do |category, event, reason = nil|
  it 'logs and tracks the event' do
    message = "IdentityVerification::#{category.to_s.classify}"

    logger_args = {
      message: message,
      event: event.to_s.titlecase,
      username: user.username
    }
    logger_args[:reason] = reason.to_s if reason

    allow(Gitlab::AppLogger).to receive(:info).and_call_original

    do_request

    expect(Gitlab::AppLogger).to have_received(:info).with(a_hash_including(logger_args))

    tracking_args = {
      category: message,
      action: event.to_s,
      property: '',
      user: user
    }
    tracking_args[:property] = reason.to_s if reason

    expect_snowplow_event(**tracking_args)
  end
end

RSpec.shared_examples 'it requires a signed in user' do
  let_it_be(:confirmed_user) do
    create(:user, created_at: IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE + 1.day)
  end

  before do
    stub_session(session_data: { verification_user_id: nil })
    sign_in confirmed_user

    do_request
  end

  context 'when the user was created after the release day' do
    it 'sets the user instance variable' do
      expect(assigns(:user)).to eq(confirmed_user)
    end

    it 'does not redirect to root path' do
      expect(response).not_to redirect_to(root_path)
    end
  end

  context 'when the user was created before the release day' do
    let_it_be(:confirmed_user) do
      create(:user, created_at: IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE - 1.day)

      it 'redirects to root path' do
        expect(response).to redirect_to(root_path)
      end
    end
  end
end

RSpec.shared_examples 'it loads reCAPTCHA' do
  before do
    allow(::Gitlab::ApplicationRateLimiter).to receive(:peek).and_call_original
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original

    stub_feature_flags(arkose_labs_phone_verification_challenge: false)
  end

  context 'when reCAPTCHA is disabled' do
    before do
      allow(Gitlab::Recaptcha).to receive(:enabled?).and_return(false)
    end

    it 'does not load recaptcha configuration' do
      expect(Gitlab::Recaptcha).not_to receive(:load_configurations!)

      do_request
    end
  end

  context 'when reCAPTCHA is enabled but daily limit has not been exceeded' do
    before do
      allow(Gitlab::Recaptcha).to receive(:enabled?).and_return(true)
      mock_rate_limit(:soft_phone_verification_transactions_limit, :peek, false)
    end

    it 'does not load reCAPTCHA configuration' do
      expect(Gitlab::Recaptcha).not_to receive(:load_configurations!)

      do_request
    end
  end

  context 'when reCAPTCHA is enabled and daily limit has been exceeded' do
    before do
      allow(Gitlab::Recaptcha).to receive(:enabled?).and_return(true)
      mock_rate_limit(:soft_phone_verification_transactions_limit, :peek, true)
    end

    it 'loads reCAPTCHA configuration' do
      expect(Gitlab::Recaptcha).to receive(:load_configurations!)

      do_request
    end
  end
end

RSpec.shared_examples 'it verifies reCAPTCHA response' do
  before do
    stub_feature_flags(arkose_labs_phone_verification_challenge: false)
  end

  context 'when feature flag soft_limit_daily_phone_verifications is disabled' do
    before do
      stub_feature_flags(soft_limit_daily_phone_verifications: false)
    end

    it 'returns 200' do
      do_request

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  context 'when reCAPTCHA is enabled' do
    before do
      allow(Gitlab::Recaptcha).to receive(:enabled?).and_return(true)
      mock_rate_limit(:soft_phone_verification_transactions_limit, :peek, false)
    end

    it 'returns 200' do
      do_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when daily limit has been reached' do
      before do
        mock_rate_limit(:soft_phone_verification_transactions_limit, :peek, true)
      end

      it_behaves_like 'logs and tracks the event', :phone, :recaptcha_shown

      context 'and when reCAPTCHA has not been solved' do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:verify_recaptcha).and_return(false)
          end
        end

        it 'returns a 400 with an error message', :aggregate_failures do
          do_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to eq(
            { message: s_('IdentityVerification|Complete verification to sign up.') }.to_json)
        end
      end

      context 'and when reCAPTCHA is solved' do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:verify_recaptcha).and_return(true)
          end
        end

        it 'returns 200' do
          do_request

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when arkose challenge is also enabled' do
          before do
            stub_feature_flags(arkose_labs_phone_verification_challenge: true)
            mock_rate_limit(:phone_verification_challenge, :peek, true, scope: user)
          end

          it 'does not expect an arkose token and returns a 200' do
            do_request

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end
  end
end

RSpec.shared_examples 'it ensures verification attempt is allowed' do |method|
  let(:target_user) { nil }

  subject { response }

  before do
    if target_user
      allow(target_user).to receive(:verification_method_allowed?).with(method: method).and_return(allowed)
    else
      allow_next_found_instance_of(User) do |instance|
        allow(instance).to receive(:verification_method_allowed?)
          .with(method: method).and_return(allowed)
      end
    end

    do_request
  end

  context 'when verification is allowed' do
    let(:allowed) { true }

    it { is_expected.to have_gitlab_http_status(:ok) }
  end

  context 'when verification is not allowed' do
    let(:allowed) { false }

    it { is_expected.to have_gitlab_http_status(:bad_request) }
  end
end

RSpec.shared_examples 'it verifies arkose token before phone verification' do
  before do
    stub_feature_flags(soft_limit_daily_phone_verifications: false)
  end

  context 'when feature flag arkose_labs_phone_verification_challenge is disabled' do
    before do
      stub_feature_flags(arkose_labs_phone_verification_challenge: false)
    end

    it 'returns 200' do
      do_request

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  context 'when arkose is enabled' do
    before do
      mock_rate_limit(:phone_verification_challenge, :peek, false, scope: user)
    end

    it 'increases verification attempts' do
      mock_rate_limit(:phone_verification_challenge, :throttled?, false, scope: user)

      do_request
    end

    it 'returns 200' do
      do_request

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when phone verification challenge rate-limit has been reached' do
      before do
        mock_rate_limit(:phone_verification_challenge, :peek, true, scope: user)
      end

      it_behaves_like 'logs and tracks the event', :phone, :arkose_challenge_shown

      context 'when token verification fails' do
        it 'returns a 400 with an error message', :aggregate_failures do
          mock_arkose_token_verification(success: false)

          do_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to eq(
            { message: s_('IdentityVerification|Complete verification to sign up.') }.to_json)
        end
      end

      context 'when token verification succeeds' do
        it 'returns a 200' do
          mock_arkose_token_verification(success: true)

          do_request

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end
end

# GET verification_state
RSpec.shared_examples 'it sets poll interval header' do
  it 'sets poll interval header' do
    do_request

    expect(response.headers.to_h).to include(Gitlab::PollingInterval::HEADER_NAME => '10000')
  end
end

# POST send_phone_verification_code
RSpec.shared_examples 'it successfully sends phone number verification code' do
  let(:response_opts) { { payload: { container: 'contents' } } }

  before do
    mock_send_phone_number_verification_code(success: true, response_opts: response_opts)
  end

  it 'responds with status 200 OK' do
    do_request

    expected_json = { status: :success }.merge(response_opts[:payload]).to_json
    expect(response.body).to eq(expected_json)
  end

  it_behaves_like 'logs and tracks the event', :phone, :sent_phone_verification_code
end

# POST send_phone_verification_code
RSpec.shared_examples 'it handles failed phone number verification code send' do
  let_it_be(:response_opts) { { message: 'message', reason: :related_to_banned_user } }

  before do
    mock_send_phone_number_verification_code(success: false, response_opts: response_opts)
  end

  it_behaves_like 'logs and tracks the event', :phone, :failed_attempt, :related_to_banned_user

  it 'responds with error message', :aggregate_failures do
    do_request

    expect(response).to have_gitlab_http_status(:bad_request)
    expect(response.body).to eq({ message: response_opts[:message], reason: response_opts[:reason] }.to_json)
  end

  context 'when the error is related to a high risk user' do
    let(:response_opts) { { message: 'message', reason: :related_to_high_risk_user } }

    it 'does not log an error' do
      expect(Gitlab::AppLogger).not_to receive(:info)

      do_request
    end
  end
end

# POST verify_phone_verification_code
RSpec.shared_examples 'it successfully verifies a phone number verification code' do
  before do
    mock_verify_phone_number_verification_code(success: true)
  end

  it 'responds with status 200 OK' do
    do_request

    expect(response.body).to eq({ status: :success }.to_json)
  end

  it_behaves_like 'logs and tracks the event', :phone, :success
end

# POST verify_phone_verification_code
RSpec.shared_examples 'it handles failed phone number code verification' do
  let_it_be(:response_opts) { { message: 'message', reason: 'reason' } }

  before do
    mock_verify_phone_number_verification_code(success: false, response_opts: response_opts)
  end

  it_behaves_like 'logs and tracks the event', :phone, :failed_attempt, :reason

  it 'responds with error message' do
    do_request

    expect(response).to have_gitlab_http_status(:bad_request)
    expect(response.body).to eq({ message: response_opts[:message], reason: response_opts[:reason] }.to_json)
  end

  context 'when multiple codes are attempted' do
    let_it_be(:param_wrapper) { described_class.name.demodulize.underscore.gsub('_controller', '') }
    let_it_be(:params) do
      { param_wrapper => { verification_code: %w[998 999] } }
    end

    it 'passes no params to VerifyCodeService' do
      do_request

      expect(::PhoneVerification::Users::VerifyCodeService).to have_received(:new).with(user, {})
    end
  end
end

# GET verify_credit_card
RSpec.shared_examples 'it verifies presence of credit_card_validation record for the user' do
  using RSpec::Parameterized::TableSyntax

  context 'when request format is html' do
    let(:params) { { format: :html } }

    it 'returns 404' do
      do_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when no credit_card_validation record exist for the user' do
    it 'returns 404' do
      do_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when a credit_card_validation record exists for the user' do
    let(:rate_limited) { false }
    let(:ip) { '1.2.3.4' }

    let_it_be(:cc_attrs) { attributes_for(:credit_card_validation) }
    let_it_be(:credit_card_validation) { create(:credit_card_validation, user: user, **cc_attrs) }

    before do
      allow_next_instance_of(ActionDispatch::Request) do |request|
        allow(request).to receive(:ip).and_return(ip)
      end

      allow_next_instance_of(described_class) do |controller|
        allow(controller).to receive(:check_rate_limit!)
          .with(:credit_card_verification_check_for_reuse, scope: ip)
          .and_return(rate_limited)
      end
    end

    it 'returns HTTP status 200 and an empty json', :aggregate_failures do
      do_request

      expect(json_response).to be_empty
      expect(response).to have_gitlab_http_status(:ok)
    end

    it_behaves_like 'logs and tracks the event', :credit_card, :success

    context 'when the user\'s credit card has been used by a banned user' do
      before do
        create(:credit_card_validation, user: create(:user, :banned), **cc_attrs)
      end

      it_behaves_like 'logs and tracks the event', :credit_card, :failed_attempt, :related_to_banned_user

      it 'bans the user' do
        expect_next_instance_of(::Users::AutoBanService, user: user, reason: :banned_credit_card) do |instance|
          expect(instance).to receive(:execute).and_call_original
        end

        expect { do_request }.to change { user.reload.banned? }.from(false).to(true)
      end

      describe 'returned error message' do
        where(:dot_com, :error_message) do
          true  | "Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance."
          false | "Your account has been blocked. Contact your GitLab administrator for assistance."
        end

        with_them do
          before do
            allow(Gitlab).to receive(:com?).and_return(dot_com)
          end

          it 'returns HTTP status 400 and a message', :aggregate_failures do
            do_request

            expect(json_response).to include({
              'message' => error_message,
              'reason' => 'related_to_banned_user'
            })
            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end
    end

    context 'when rate limited' do
      let(:rate_limited) { true }

      it 'returns HTTP status 400 and a message', :aggregate_failures do
        do_request

        expect(json_response).to include({
          'message' => format(s_("IdentityVerification|You've reached the maximum amount of tries. " \
                                 "Wait %{interval} and try again."), { interval: 'about 1 hour' })
        })
        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it_behaves_like 'logs and tracks the event', :credit_card, :failed_attempt, :rate_limited
    end
  end
end

# PATCH toggle_phone_exemption
RSpec.shared_examples 'toggles phone number verification exemption for the user' do
  let(:target_user) { nil }

  let(:exemption_offered) { true }

  before do
    if target_user
      allow(target_user).to receive(:offer_phone_number_exemption?).and_return(exemption_offered)
    else
      allow_next_found_instance_of(User) do |instance|
        allow(instance).to receive(:offer_phone_number_exemption?).and_return(exemption_offered)
      end
    end
  end

  it 'toggles phone exemption' do
    expect { do_request }.to change { User.find(user.id).exempt_from_phone_number_verification? }.to(true)
  end

  it 'returns verification methods and state' do
    do_request

    expect(json_response.keys).to include('verification_methods', 'verification_state')
  end

  it_behaves_like 'logs and tracks the event', :toggle_phone_exemption, :success

  context 'when phone exemption is not offered for the user' do
    let(:exemption_offered) { false }

    it_behaves_like 'logs and tracks the event', :toggle_phone_exemption, :failed

    it 'returns an empty response with a bad request status', :aggregate_failures do
      do_request

      expect(json_response).to be_empty

      expect(response).to have_gitlab_http_status(:bad_request)
    end
  end
end
