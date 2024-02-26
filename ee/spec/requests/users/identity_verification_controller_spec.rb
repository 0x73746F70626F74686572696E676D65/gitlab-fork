# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::IdentityVerificationController, :clean_gitlab_redis_sessions, :clean_gitlab_redis_rate_limiting,
  feature_category: :system_access do
  include SessionHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:unconfirmed_user) { create(:user, :unconfirmed, :low_risk) }
  let_it_be(:confirmed_user) { create(:user, :low_risk) }
  let_it_be(:invalid_verification_user_id) { non_existing_record_id }

  let(:successful_verification_response) do
    json = Gitlab::Json.parse(
      File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response.json'))
    )
    response = Arkose::VerifyResponse.new(json)
    ServiceResponse.success(payload: { response: response })
  end

  let(:failed_verification_response) do
    json = Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/invalid_token.json')))
    response = Arkose::VerifyResponse.new(json)
    ServiceResponse.error(message: response.error)
  end

  let(:verification_service_response) { successful_verification_response }
  let(:status_service_response) { ServiceResponse.success }
  let(:is_arkose_enabled) { true }

  before do
    stub_application_setting_enum('email_confirmation_setting', 'hard')
    stub_application_setting(require_admin_approval_after_user_signup: false)

    allow(::Gitlab::ApplicationRateLimiter).to receive(:peek).and_call_original
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original

    allow(::Arkose::Settings).to receive(:enabled?).and_return(is_arkose_enabled)

    allow_next_instance_of(::Arkose::StatusService) do |instance|
      allow(instance).to receive(:execute).and_return(status_service_response)
    end
  end

  shared_examples 'it requires a valid verification_user_id' do |expected_response_code|
    let(:response_code) { expected_response_code || :ok }

    context 'when session contains an invalid `verification_user_id`' do
      before do
        stub_session(verification_user_id: invalid_verification_user_id)
      end

      it 'handles sticking' do
        allow(User.sticking).to receive(:find_caught_up_replica)
        .and_call_original

        expect(User.sticking)
          .to receive(:find_caught_up_replica)
          .with(:user, invalid_verification_user_id)

        do_request

        stick_object = request.env[::Gitlab::Database::LoadBalancing::RackMiddleware::STICK_OBJECT].first
        expect(stick_object[0]).to eq(User.sticking)
        expect(stick_object[1]).to eq(:user)
        expect(stick_object[2]).to eq(invalid_verification_user_id)
      end

      it 'redirects to root path' do
        do_request

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when session contains a valid `verification_user_id`' do
      before do
        stub_session(verification_user_id: unconfirmed_user.id)

        do_request
      end

      it 'sets the user instance variable' do
        expect(assigns(:user)).to eq(unconfirmed_user)
      end

      it 'renders identity verification page' do
        expect(response).to have_gitlab_http_status(response_code)
      end
    end

    context 'when session is empty but a confirmed user is logged in' do
      before do
        stub_session(verification_user_id: nil)
        sign_in confirmed_user

        do_request
      end

      it 'sets the user instance variable' do
        expect(assigns(:user)).to eq(confirmed_user)
      end

      it 'does not redirect to root path' do
        expect(response).not_to redirect_to(root_path)
      end
    end
  end

  shared_examples 'it requires an unconfirmed user' do |expected_response_code|
    subject { response }

    let(:response_code) { expected_response_code || :ok }

    before do
      stub_session(verification_user_id: user.id)

      do_request
    end

    context 'when session contains a `verification_user_id` from a confirmed user' do
      let_it_be(:user) { confirmed_user }

      it { is_expected.to redirect_to(success_identity_verification_path) }
    end

    context 'when session contains a `verification_user_id` from an unconfirmed user' do
      let_it_be(:user) { unconfirmed_user }

      it { is_expected.to have_gitlab_http_status(response_code) }
    end
  end

  shared_examples 'it ensures verification attempt is allowed' do |method|
    subject { response }

    before do
      allow_next_found_instance_of(User) do |instance|
        allow(instance).to receive(:verification_method_allowed?)
          .with(method: method).and_return(allowed)
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

  shared_examples 'it requires oauth users to go through ArkoseLabs challenge' do
    let(:user) { create(:omniauth_user, :unconfirmed) }

    before do
      stub_session(verification_user_id: user.id)

      do_request
    end

    subject { response }

    it { is_expected.to redirect_to(arkose_labs_challenge_identity_verification_path) }

    context 'when user has an arkose_risk_band' do
      let(:user) { create(:omniauth_user, :unconfirmed, :low_risk) }

      it { is_expected.not_to redirect_to(arkose_labs_challenge_identity_verification_path) }
    end

    context 'when arkose is disabled' do
      let(:is_arkose_enabled) { false }

      it { is_expected.not_to redirect_to(arkose_labs_challenge_identity_verification_path) }
    end
  end

  shared_examples 'logs and tracks the event' do |category, event, reason = nil|
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

  shared_examples 'it verifies arkose token before phone verification' do
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
        allow(::Gitlab::ApplicationRateLimiter)
        .to receive(:peek)
        .with(:phone_verification_challenge, scope: user)
        .and_return(false)
      end

      it 'increases verification attempts' do
        expect(::Gitlab::ApplicationRateLimiter)
          .to receive(:throttled?)
          .with(:phone_verification_challenge, scope: user)

        do_request
      end

      it 'returns 200' do
        do_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when phone verification challenge rate-limit has been reached' do
        let(:params) do
          { arkose_labs_token: 'verification-token', identity_verification: { phone_number: '555' } }
        end

        before do
          allow(::Gitlab::ApplicationRateLimiter)
            .to receive(:peek)
            .with(:phone_verification_challenge, scope: user)
            .and_return(true)

          verification_params = { session_token: params[:arkose_labs_token], user: nil }
          allow_next_instance_of(Arkose::TokenVerificationService, verification_params) do |instance|
            allow(instance).to receive(:execute).and_return(verification_service_response)
          end
        end

        it_behaves_like 'logs and tracks the event', :phone, :arkose_challenge_shown

        context 'when token verification fails' do
          let(:verification_service_response) { failed_verification_response }

          it 'returns a 400 with an error message', :aggregate_failures do
            do_request

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to eq(
              { message: s_('IdentityVerification|Complete verification to sign up.') }.to_json)
          end
        end

        context 'when token verification succeeds' do
          it 'returns a 200' do
            do_request

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end
  end

  shared_examples 'it loads reCAPTCHA' do
    before do
      stub_feature_flags(arkose_labs_phone_verification_challenge: false)
      stub_session(verification_user_id: unconfirmed_user.id)
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
        allow(::Gitlab::ApplicationRateLimiter)
          .to receive(:peek)
          .with(:soft_phone_verification_transactions_limit, scope: nil)
          .and_return(false)
      end

      it 'does not load reCAPTCHA configuration' do
        expect(Gitlab::Recaptcha).not_to receive(:load_configurations!)

        do_request
      end
    end

    context 'when reCAPTCHA is enabled and daily limit has been exceeded' do
      before do
        allow(Gitlab::Recaptcha).to receive(:enabled?).and_return(true)
        allow(::Gitlab::ApplicationRateLimiter)
          .to receive(:peek)
          .with(:soft_phone_verification_transactions_limit, scope: nil)
          .and_return(true)
      end

      it 'loads reCAPTCHA configuration' do
        expect(Gitlab::Recaptcha).to receive(:load_configurations!)

        do_request
      end
    end
  end

  shared_examples 'it verifies reCAPTCHA response' do
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

        allow(::Gitlab::ApplicationRateLimiter)
          .to receive(:peek)
          .with(:soft_phone_verification_transactions_limit, scope: nil)
          .and_return(false)
      end

      it 'returns 200' do
        do_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when daily limit has been reached' do
        before do
          allow(::Gitlab::ApplicationRateLimiter)
          .to receive(:peek)
          .with(:soft_phone_verification_transactions_limit, scope: nil)
          .and_return(true)
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

              allow(::Gitlab::ApplicationRateLimiter)
                .to receive(:peek)
                .with(:phone_verification_challenge, scope: user)
                .and_return(true)
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

  describe 'GET show' do
    subject(:do_request) { get identity_verification_path }

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'
    it_behaves_like 'it loads reCAPTCHA'

    it 'renders template show with layout minimal' do
      stub_session(verification_user_id: unconfirmed_user.id)

      do_request

      expect(response).to render_template('show', layout: 'minimal')
    end

    context 'with a banned user' do
      let_it_be_with_reload(:user) { unconfirmed_user }

      where(:dot_com, :error_message) do
        true  | "Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance."
        false | "Your account has been blocked. Contact your GitLab administrator for assistance."
      end

      with_them do
        before do
          allow(Gitlab).to receive(:com?).and_return(dot_com)
          stub_session(verification_user_id: user.id)
          user.ban

          do_request
        end

        it 'redirects to the sign-in page with an error message', :aggregate_failures do
          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(new_user_session_path)
          expect(flash[:alert]).to eq(error_message)
        end

        it 'deletes the verification_user_id from the session' do
          expect(request.session.has_key?(:verification_user_id)).to eq(false)
        end
      end
    end
  end

  describe 'GET verification_state' do
    subject(:do_request) { get verification_state_identity_verification_path }

    it_behaves_like 'it requires a valid verification_user_id'

    context 'with a unverified user' do
      let_it_be(:user) { unconfirmed_user }

      before do
        stub_session(verification_user_id: user.id)
      end

      it 'returns verification methods and state' do
        do_request

        expect(json_response).to eq({
          'verification_methods' => ["email"],
          'verification_state' => { "email" => false }
        })
      end

      describe 'poll interval header' do
        it 'is added' do
          do_request

          expect(response.headers.to_h).to include(Gitlab::PollingInterval::HEADER_NAME => '10000')
        end
      end
    end

    context 'with a verified user' do
      let_it_be(:user) { confirmed_user }

      before do
        sign_in confirmed_user
      end

      it 'returns verification methods and state' do
        do_request

        expect(json_response).to eq({
          'verification_methods' => user.required_identity_verification_methods,
          'verification_state' => user.identity_verification_state
        })
      end
    end
  end

  describe 'POST verify_email_code' do
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:params) { { identity_verification: { code: '123456' } } }
    let_it_be(:service_response) { { status: :success } }

    subject(:do_request) { post verify_email_code_identity_verification_path(params) }

    before do
      allow_next_instance_of(::Users::EmailVerification::ValidateTokenService) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end

      stub_session(verification_user_id: user.id)
    end

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'

    context 'when validation was successful' do
      it 'confirms the user', :freeze_time do
        expect { do_request }.to change { user.reload.confirmed_at }.from(nil).to(Time.current)
      end

      it_behaves_like 'logs and tracks the event', :email, :success

      it 'renders the result as json' do
        do_request

        expect(response.body).to eq(service_response.to_json)
      end
    end

    context 'when failing to validate' do
      let_it_be(:service_response) { { status: :failure, reason: 'reason', message: 'message' } }

      it_behaves_like 'logs and tracks the event', :email, :failed_attempt, :reason

      it 'renders the result as json' do
        do_request

        expect(response.body).to eq(service_response.to_json)
      end
    end
  end

  describe 'POST resend_email_code' do
    let_it_be(:user) { unconfirmed_user }

    subject(:do_request) { post resend_email_code_identity_verification_path }

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'

    context 'when rate limited' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:peek)
          .with(:soft_phone_verification_transactions_limit, scope: nil).and_return(false)

        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?)
          .with(:email_verification_code_send, scope: user).and_return(true)

        stub_session(verification_user_id: user.id)

        do_request
      end

      it 'renders the result as json' do
        expect(response.body).to eq({
          status: :failure,
          message: format(s_("IdentityVerification|You've reached the maximum amount of resends. Wait %{interval} "\
            'and try again.'), interval: 'about 1 hour')
        }.to_json)
      end
    end

    context 'when successful' do
      let_it_be(:new_token) { '123456' }
      let_it_be(:encrypted_token) { Devise.token_generator.digest(User, unconfirmed_user.email, new_token) }

      before do
        allow_next_instance_of(::Users::EmailVerification::GenerateTokenService) do |service|
          allow(service).to receive(:generate_token).and_return(new_token)
        end
        stub_session(verification_user_id: user.id)
      end

      it 'sets the confirmation_sent_at time', :freeze_time do
        expect { do_request }.to change { user.reload.confirmation_sent_at }.to(Time.current)
      end

      it 'sets the confirmation_token to the encrypted custom token' do
        expect { do_request }.to change { user.reload.confirmation_token }.to(encrypted_token)
      end

      it 'sends the confirmation instructions email' do
        expect(::Notify).to receive(:confirmation_instructions_email)
          .with(user.email, token: new_token).once.and_call_original

        do_request
      end

      it_behaves_like 'logs and tracks the event', :email, :sent_instructions

      it 'renders the result as json' do
        do_request

        expect(response.body).to eq({ status: :success }.to_json)
      end
    end
  end

  describe 'POST send_phone_verification_code' do
    let_it_be(:unconfirmed_user) { create(:user, :medium_risk) }
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:service_response) { ServiceResponse.success(payload: { container: 'contents' }) }
    let_it_be(:params) do
      { identity_verification: { country: 'US', international_dial_code: '1', phone_number: '555' } }
    end

    subject(:do_request) { post send_phone_verification_code_identity_verification_path(params) }

    before do
      allow_next_instance_of(::PhoneVerification::Users::SendVerificationCodeService) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end
      stub_session(verification_user_id: user.id)
    end

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'
    it_behaves_like 'it ensures verification attempt is allowed', 'phone'
    it_behaves_like 'it verifies arkose token before phone verification'
    it_behaves_like 'it verifies reCAPTCHA response'

    context 'when sending the code is successful' do
      it 'responds with status 200 OK' do
        do_request

        expected_json = { status: :success }.merge(service_response.payload).to_json
        expect(response.body).to eq(expected_json)
      end

      it_behaves_like 'logs and tracks the event', :phone, :sent_phone_verification_code
    end

    context 'when sending the code is unsuccessful' do
      let_it_be(:service_response) { ServiceResponse.error(message: 'message', reason: :related_to_banned_user) }

      it_behaves_like 'logs and tracks the event', :phone, :failed_attempt, :related_to_banned_user

      it 'responds with error message', :aggregate_failures do
        do_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to eq({ message: service_response.message, reason: service_response.reason }.to_json)
      end

      context 'when the `identity_verification_auto_ban` feature flag is disabled' do
        before do
          stub_feature_flags(identity_verification_auto_ban: false)
        end

        it 'responds without a reason' do
          do_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to eq({ message: service_response.message }.to_json)
        end
      end

      context 'when the error is related to a high risk user' do
        let(:service_response) { ServiceResponse.error(message: 'message', reason: :related_to_high_risk_user) }

        it 'does not log an error' do
          expect(Gitlab::AppLogger).not_to receive(:info)

          do_request
        end
      end
    end
  end

  describe 'POST verify_phone_verification_code' do
    let_it_be(:unconfirmed_user) { create(:user, :medium_risk) }
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:service_response) { ServiceResponse.success }
    let_it_be(:params) do
      { identity_verification: { verification_code: '999' } }
    end

    subject(:do_request) { post verify_phone_verification_code_identity_verification_path(params) }

    before do
      allow_next_instance_of(::PhoneVerification::Users::VerifyCodeService) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end
      stub_session(verification_user_id: user.id)
    end

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'
    it_behaves_like 'it ensures verification attempt is allowed', 'phone'
    it_behaves_like 'it verifies arkose token before phone verification'
    it_behaves_like 'it verifies reCAPTCHA response'

    context 'when code verification is successful' do
      it 'responds with status 200 OK' do
        do_request

        expect(response.body).to eq({ status: :success }.to_json)
      end

      it_behaves_like 'logs and tracks the event', :phone, :success
    end

    context 'when code verification is unsuccessful' do
      let_it_be(:service_response) { ServiceResponse.error(message: 'message', reason: 'reason') }

      it_behaves_like 'logs and tracks the event', :phone, :failed_attempt, :reason

      it 'responds with error message' do
        do_request

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to eq({ message: service_response.message, reason: service_response.reason }.to_json)
      end
    end
  end

  shared_examples 'it requires a user without an arkose risk_band' do
    let_it_be(:user_without_risk_band) { create(:user) }
    let_it_be(:user_with_risk_band) { create(:user) }

    before do
      stub_session(verification_user_id: user&.id)
      request
    end

    subject { response }

    context 'when session contains no `verification_user_id`' do
      let(:user) { nil }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when session contains a `verification_user_id` from a user with an arkose risk_band' do
      let(:user) { user_with_risk_band }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when session contains a `verification_user_id` from a user without an arkose risk_band' do
      let(:user) { user_without_risk_band }

      it { is_expected.to have_gitlab_http_status(:ok) }
    end
  end

  describe 'POST verify_arkose_labs_session' do
    let_it_be(:user) { create(:user, :unconfirmed) }

    let(:params) { { arkose_labs_token: 'fake-token' } }
    let(:do_request) { post verify_arkose_labs_session_identity_verification_path, params: params }
    let(:service_response) { successful_verification_response }

    before do
      stub_session(verification_user_id: user.id)

      allow_next_instance_of(Arkose::TokenVerificationService) do |instance|
        allow(instance).to receive(:execute).and_return(service_response)
      end
    end

    it_behaves_like 'it requires a valid verification_user_id', :redirect
    it_behaves_like 'it requires an unconfirmed user', :redirect

    describe 'token verification' do
      before do
        init_params = { session_token: params[:arkose_labs_token], user: user }
        allow_next_instance_of(Arkose::TokenVerificationService, init_params) do |instance|
          allow(instance).to receive(:execute).and_return(service_response)
        end
      end

      context 'when it fails' do
        let(:service_response) { ServiceResponse.error(message: 'Captcha was not solved') }

        it 'renders arkose_labs_challenge with the correct alert flash' do
          do_request

          expect(flash[:alert]).to include(s_('IdentityVerification|Complete verification to sign up.'))
          expect(response).to render_template('arkose_labs_challenge')
        end

        context 'when Arkose is down' do
          let(:status_service_response) { ServiceResponse.error(message: 'Arkose outage') }

          it 'marks the user as Arkose-verified' do
            expect { do_request }.to change { user.arkose_verified? }.from(false).to(true)

            expect(response).to redirect_to(identity_verification_path)
          end
        end
      end

      context 'when it succeeds' do
        it 'redirects to show action' do
          do_request

          expect(response).to redirect_to(identity_verification_path)
        end

        describe 'phone verification service daily transaction limit check' do
          it 'is executed' do
            service = PhoneVerification::Users::RateLimitService
            expect(service).to receive(:assume_user_high_risk_if_daily_limit_exceeded!).with(user)

            do_request
          end
        end
      end
    end
  end

  describe 'GET arkose_labs_challenge' do
    let_it_be(:user) { create(:user, :unconfirmed) }

    let(:do_request) { get arkose_labs_challenge_identity_verification_path }

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'

    it 'renders arkose_labs_challenge template' do
      stub_session(verification_user_id: user.id)
      do_request

      expect(response).to render_template('arkose_labs_challenge', layout: 'minimal')
    end
  end

  describe 'GET success' do
    let(:stored_user_return_to_path) { '/user/return/to/path' }
    let(:user) { confirmed_user }
    let!(:member_invite) { create(:project_member, :invited, invite_email: user.email) }

    before do
      stub_session(verification_user_id: user.id, user_return_to: stored_user_return_to_path)
      get success_identity_verification_path
    end

    context 'when not yet verified' do
      let(:user) { unconfirmed_user }

      it 'redirects back to identity_verification_path' do
        expect(response).to redirect_to(identity_verification_path)
      end
    end

    context 'when verified' do
      it 'accepts pending invitations' do
        expect(member_invite.reload).not_to be_invite
      end

      it 'signs in the user' do
        expect(request.env['warden']).to be_authenticated
      end

      it 'deletes the verification_user_id from the session' do
        expect(request.session.has_key?(:verification_user_id)).to eq(false)
      end
    end

    it 'renders the template with the after_sign_in_path_for variable', :aggregate_failures do
      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('successful_verification', layout: 'minimal')
      expect(assigns(:redirect_url)).to eq(stored_user_return_to_path)
    end

    context 'when user is in subscription onboarding', :saas do
      let(:stored_user_return_to_path) { new_subscriptions_path(plan_id: 'bronze_id') }

      it 'does not empty out the stored location for user', :aggregate_failures do
        expect(response).to have_gitlab_http_status(:ok)
        expect(assigns(:redirect_url)).to eq(stored_user_return_to_path)
        expect(controller.stored_location_for(:user)).to eq(stored_user_return_to_path)
      end
    end

    it 'tracks phone_verification_for_low_risk_users registration_completed event', :experiment do
      expect(experiment(:phone_verification_for_low_risk_users))
        .to track(:registration_completed).on_next_instance.with_context(user: user)

      get success_identity_verification_path
    end
  end

  describe 'GET verify_credit_card' do
    let(:params) { { format: :json } }

    let_it_be(:user) { unconfirmed_user }

    before do
      stub_session(verification_user_id: user.id)

      allow_next_found_instance_of(User) do |instance|
        allow(instance).to receive(:verification_method_allowed?).and_return(true)
      end
    end

    subject(:do_request) { get verify_credit_card_identity_verification_path(params) }

    context 'when request format is html' do
      let(:params) { { format: :html } }

      it 'returns 404' do
        do_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when no credit_card_validation record exist for the user' do
      let(:params) { { format: :json } }

      it 'returns 404' do
        do_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when request format is json' do
      let(:params) { { format: :json } }
      let(:rate_limited) { false }
      let(:ip) { '1.2.3.4' }
      let(:used_by_banned_user) { false }

      let_it_be(:credit_card_validation) { create(:credit_card_validation, user: user) }

      before do
        allow_next_found_instance_of(::Users::CreditCardValidation) do |cc|
          allow(cc).to receive(:used_by_banned_user?).and_return(used_by_banned_user)
        end

        allow_next_instance_of(ActionDispatch::Request) do |request|
          allow(request).to receive(:ip).and_return(ip)
        end

        allow_next_instance_of(described_class) do |controller|
          allow(controller).to receive(:check_rate_limit!)
            .with(:credit_card_verification_check_for_reuse, scope: ip)
            .and_return(rate_limited)
        end
      end

      it_behaves_like 'it requires a valid verification_user_id'

      context 'when the user\'s credit card has not been used by a banned user' do
        it 'returns HTTP status 200 and an empty json', :aggregate_failures do
          do_request

          expect(json_response).to be_empty
          expect(response).to have_gitlab_http_status(:ok)
        end

        it_behaves_like 'logs and tracks the event', :credit_card, :success
      end

      shared_examples 'returns HTTP status 400 and a message' do
        it 'returns HTTP status 400 and a message', :aggregate_failures do
          do_request

          expect(json_response).to include({
            'message' => format(s_("IdentityVerification|You've reached the maximum amount of tries. " \
                                   'Wait %{interval} and try again.'), { interval: 'about 1 hour' })
          })
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when the user\'s credit card has been used by a banned user' do
        let(:used_by_banned_user) { true }

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

        context 'when the `identity_verification_auto_ban` feature flag is disabled' do
          before do
            stub_feature_flags(identity_verification_auto_ban: false)
          end

          it 'does not ban the user' do
            expect { do_request }.not_to change { user.reload.banned? }
          end

          it 'returns HTTP status 400 and a message', :aggregate_failures do
            do_request

            expect(json_response).to eq(
              'message' => s_('IdentityVerification|There was a problem with the credit card details you entered. ' \
                              'Use a different credit card and try again.'))
            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      context 'when rate limited' do
        let(:used_by_banned_user) { false }
        let(:rate_limited) { true }

        it_behaves_like 'returns HTTP status 400 and a message'
        it_behaves_like 'logs and tracks the event', :credit_card, :failed_attempt, :rate_limited
      end

      it_behaves_like 'it ensures verification attempt is allowed', 'credit_card'
    end
  end

  describe 'POST verify_credit_card_captcha' do
    let_it_be(:user) { unconfirmed_user }

    before do
      stub_session(verification_user_id: user.id)
    end

    subject(:do_request) { post verify_credit_card_captcha_identity_verification_path }

    it_behaves_like 'it verifies reCAPTCHA response'
  end

  describe 'PATCH toggle_phone_exemption' do
    let_it_be(:user) { unconfirmed_user }

    let(:offer_phone_number_exemption) { true }

    subject(:do_request) { patch toggle_phone_exemption_identity_verification_path(format: :json) }

    before do
      stub_session(verification_user_id: user.id)

      allow_next_found_instance_of(User) do |user|
        allow(user).to receive(:offer_phone_number_exemption?).and_return(offer_phone_number_exemption)
      end
    end

    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires a valid verification_user_id'

    context 'when offering phone exemption' do
      it 'toggles phone exemption' do
        expect { do_request }.to change { User.find(user.id).exempt_from_phone_number_verification? }.to(true)
      end

      it 'returns verification methods and state' do
        do_request

        expect(json_response).to eq({
          'verification_methods' => %w[email credit_card],
          'verification_state' => { "credit_card" => false, "email" => false }
        })
      end

      it_behaves_like 'logs and tracks the event', :toggle_phone_exemption, :success
    end

    context 'when not offering phone exemption' do
      let(:offer_phone_number_exemption) { false }

      it_behaves_like 'logs and tracks the event', :toggle_phone_exemption, :failed

      it 'returns an empty response with a bad request status', :aggregate_failures do
        do_request

        expect(json_response).to be_empty

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end
end
