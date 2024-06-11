# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::RegistrationsIdentityVerificationController, :clean_gitlab_redis_sessions,
  :clean_gitlab_redis_rate_limiting, feature_category: :instance_resiliency do
  include SessionHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:unconfirmed_user) { create(:user, :unconfirmed, :low_risk) }
  let_it_be(:confirmed_user, reload: true) { create(:user, :low_risk) }
  let_it_be(:invalid_verification_user_id) { non_existing_record_id }

  before do
    stub_saas_features(identity_verification: true)
    stub_application_setting_enum('email_confirmation_setting', 'hard')
    stub_application_setting(require_admin_approval_after_user_signup: false)

    allow(::Gitlab::ApplicationRateLimiter).to receive(:peek).and_call_original
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_call_original

    allow_next_found_instance_of(User) do |instance|
      allow(instance).to receive(:verification_method_allowed?).and_return(true)
    end
  end

  shared_examples 'it requires a valid verification_user_id' do |expected_response_code|
    let(:response_code) { expected_response_code || :ok }

    context 'when session contains an invalid `verification_user_id`' do
      before do
        stub_session(session_data: { verification_user_id: invalid_verification_user_id })
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
        stub_session(session_data: { verification_user_id: unconfirmed_user.id })

        do_request
      end

      it 'sets the user instance variable' do
        expect(assigns(:user)).to eq(unconfirmed_user)
      end

      it 'renders identity verification page' do
        expect(response).to have_gitlab_http_status(response_code)
      end
    end

    it_behaves_like 'it requires a signed in user'
  end

  shared_examples 'it requires an unconfirmed user' do |expected_response_code|
    subject { response }

    let(:response_code) { expected_response_code || :ok }

    before do
      stub_session(session_data: { verification_user_id: user.id })

      do_request
    end

    context 'when session contains a `verification_user_id` from a confirmed user' do
      let_it_be(:user) { confirmed_user }

      it { is_expected.to redirect_to(success_signup_identity_verification_path) }
    end

    context 'when session contains a `verification_user_id` from an unconfirmed user' do
      let_it_be(:user) { unconfirmed_user }

      it { is_expected.to have_gitlab_http_status(response_code) }
    end
  end

  shared_examples 'it requires oauth users to go through ArkoseLabs challenge' do
    let(:user) { create(:omniauth_user, :unconfirmed) }
    let(:arkose_enabled) { true }

    before do
      allow(::Arkose::Settings).to receive(:enabled?).and_return(arkose_enabled)

      stub_session(session_data: { verification_user_id: user.id })

      do_request
    end

    subject { response }

    it { is_expected.to redirect_to(arkose_labs_challenge_signup_identity_verification_path) }

    context 'when user has an arkose_risk_band' do
      let(:user) { create(:omniauth_user, :unconfirmed, :low_risk) }

      it { is_expected.not_to redirect_to(arkose_labs_challenge_signup_identity_verification_path) }
    end

    context 'when arkose is disabled' do
      let(:arkose_enabled) { false }

      it { is_expected.not_to redirect_to(arkose_labs_challenge_signup_identity_verification_path) }
    end
  end

  describe 'GET show' do
    subject(:do_request) { get signup_identity_verification_path }

    before do
      stub_session(session_data: { verification_user_id: unconfirmed_user.id })
    end

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'

    it 'renders template show with layout minimal' do
      do_request

      expect(response).to render_template('show', layout: 'minimal')
    end

    context 'for signup_intent_step_one experiment' do
      let(:experiment) { instance_double(ApplicationExperiment) }

      it 'tracks signup_intent_step_one experiment events' do
        stub_session(session_data: { verification_user_id: unconfirmed_user.id })

        allow_next_instance_of(described_class) do |controller|
          allow(controller)
            .to receive(:experiment)
                  .with(:signup_intent_step_one, actor: unconfirmed_user)
                  .and_return(experiment)
        end

        expect(experiment).to receive(:run)
        expect(experiment).to receive(:track).with(:render_identity_verification, label: 'free_registration')

        do_request
      end
    end

    context 'with a banned user' do
      let_it_be_with_reload(:user) { unconfirmed_user }

      before do
        stub_session(session_data: { verification_user_id: user.id })
        user.ban

        do_request
      end

      it 'redirects to the sign-in page with an error message', :aggregate_failures do
        expect(response).to have_gitlab_http_status(:redirect)
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert])
          .to eq("Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance.")
      end

      it 'deletes the verification_user_id from the session' do
        expect(request.session.has_key?(:verification_user_id)).to eq(false)
      end
    end
  end

  describe 'GET restricted' do
    subject(:get_restricted) { get restricted_signup_identity_verification_path }

    context "when feature `prevent_registration_from_china` is enabled" do
      it 'returns the template with a redirect', :aggregate_failures do
        get_restricted

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context "when feature `prevent_registration_from_china` is not enabled" do
      before do
        stub_feature_flags(prevent_registration_from_china: false)
      end

      it 'returns not found', :aggregate_failures do
        get_restricted

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET verification_state' do
    subject(:do_request) { get verification_state_signup_identity_verification_path }

    it_behaves_like 'it requires a valid verification_user_id'

    context 'with an unverified user' do
      let_it_be(:user) { unconfirmed_user }

      before do
        stub_session(session_data: { verification_user_id: user.id })
      end

      it 'returns verification methods and state', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/463198' do
        do_request

        expect(json_response).to eq({
          'verification_methods' => user.required_identity_verification_methods,
          'verification_state' => user.identity_verification_state,
          'methods_requiring_arkose_challenge' => []
        })
      end

      it_behaves_like 'it sets poll interval header'

      describe 'methods_requiring_arkose_challenge' do
        subject do
          do_request

          json_response['methods_requiring_arkose_challenge']
        end

        where(:required_methods, :methods_requiring_challenge) do
          %w[email]                   | []
          %w[email phone]             | %w[phone]
          %w[email phone credit_card] | %w[phone]
          %w[email credit_card phone] | %w[credit_card]
          %w[email credit_card]       | %w[credit_card]
          %w[phone]                   | %w[phone]
          %w[phone credit_card]       | %w[phone]
          %w[credit_card phone]       | %w[credit_card]
          %w[credit_card]             | %w[credit_card]
        end

        with_them do
          before do
            allow_next_found_instance_of(User) do |instance|
              allow(instance).to receive(:required_identity_verification_methods).and_return(required_methods)
            end
          end

          it { is_expected.to match_array(methods_requiring_challenge) }

          context 'when identity_verification_arkose_challenge is disabled' do
            before do
              stub_feature_flags(identity_verification_arkose_challenge: false)
            end

            it { is_expected.to eq [] }
          end
        end
      end
    end
  end

  describe 'POST verify_email_code' do
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:params) { { registrations_identity_verification: { code: '123456' } } }
    let_it_be(:service_response) { { status: :success } }

    subject(:do_request) { post verify_email_code_signup_identity_verification_path(params) }

    before do
      allow_next_instance_of(::Users::EmailVerification::ValidateTokenService) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end

      stub_session(session_data: { verification_user_id: user.id })
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

    subject(:do_request) { post resend_email_code_signup_identity_verification_path }

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'

    context 'when rate limited' do
      before do
        mock_rate_limit(:soft_phone_verification_transactions_limit, :peek, false)
        mock_rate_limit(:email_verification_code_send, :throttled?, true, scope: user)

        stub_session(session_data: { verification_user_id: user.id })

        do_request
      end

      it 'renders the result as json' do
        expect(response.body).to eq({
          status: :failure,
          message: format(s_("IdentityVerification|You've reached the maximum amount of resends. Wait %{interval} " \
                             "and try again."), interval: 'about 1 hour')
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
        stub_session(session_data: { verification_user_id: user.id })
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
    let_it_be(:params) do
      { registrations_identity_verification: { country: 'US', international_dial_code: '1', phone_number: '555' } }
    end

    subject(:do_request) { post send_phone_verification_code_signup_identity_verification_path(params) }

    before do
      stub_session(session_data: { verification_user_id: user.id })
      mock_arkose_token_verification(success: true)
    end

    describe 'before action hooks' do
      before do
        mock_send_phone_number_verification_code(success: true)
      end

      it_behaves_like 'it requires a valid verification_user_id'
      it_behaves_like 'it requires an unconfirmed user'
      it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'
      it_behaves_like 'it ensures verification attempt is allowed', 'phone'
      it_behaves_like 'it verifies arkose token', 'phone'
    end

    it_behaves_like 'it successfully sends phone number verification code'
    it_behaves_like 'it handles failed phone number verification code send'
  end

  describe 'POST verify_phone_verification_code' do
    let_it_be(:unconfirmed_user) { create(:user, :medium_risk) }
    let_it_be(:user) { unconfirmed_user }
    let_it_be(:params) do
      { registrations_identity_verification: { verification_code: '999' } }
    end

    subject(:do_request) { post verify_phone_verification_code_signup_identity_verification_path(params) }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    describe 'before action hooks' do
      before do
        mock_verify_phone_number_verification_code(success: true)
      end

      it_behaves_like 'it requires a valid verification_user_id'
      it_behaves_like 'it requires an unconfirmed user'
      it_behaves_like 'it requires oauth users to go through ArkoseLabs challenge'
      it_behaves_like 'it ensures verification attempt is allowed', 'phone'
    end

    it_behaves_like 'it successfully verifies a phone number verification code'
    it_behaves_like 'it handles failed phone number code verification'
  end

  shared_examples 'it requires a user without an arkose risk_band' do
    let_it_be(:user_without_risk_band) { create(:user) }
    let_it_be(:user_with_risk_band) { create(:user) }

    before do
      stub_session(session_data: { verification_user_id: user&.id })
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
    let(:do_request) { post verify_arkose_labs_session_signup_identity_verification_path, params: params }

    before do
      stub_session(session_data: { verification_user_id: user.id })

      mock_arkose_token_verification(success: true)
    end

    it_behaves_like 'it requires a valid verification_user_id', :redirect
    it_behaves_like 'it requires an unconfirmed user', :redirect

    describe 'token verification' do
      context 'when it fails' do
        it 'renders arkose_labs_challenge with the correct alert flash' do
          mock_arkose_token_verification(success: false)

          do_request

          expect(flash[:alert]).to include(s_('IdentityVerification|Complete verification to sign up.'))
          expect(response).to render_template('arkose_labs_challenge')
        end

        context 'when Arkose is down' do
          it 'marks the user as Arkose-verified' do
            mock_arkose_token_verification(success: false, service_down: true)

            expect { do_request }.to change { user.arkose_verified? }.from(false).to(true)

            expect(response).to redirect_to(signup_identity_verification_path)
          end
        end
      end

      context 'when it succeeds' do
        it 'redirects to show action' do
          mock_arkose_token_verification(success: true)

          do_request

          expect(response).to redirect_to(signup_identity_verification_path)
        end

        it_behaves_like 'sets arkose_challenge_solved session variable'

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

    let(:do_request) { get arkose_labs_challenge_signup_identity_verification_path }

    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'it requires an unconfirmed user'

    it 'renders arkose_labs_challenge template' do
      stub_session(session_data: { verification_user_id: user.id })
      do_request

      expect(response).to render_template('arkose_labs_challenge', layout: 'minimal')
    end
  end

  describe 'GET success' do
    let(:stored_user_return_to_path) { '/user/return/to/path' }
    let(:return_to_entries) { { user_return_to: stored_user_return_to_path } }
    let(:user) { confirmed_user }

    before do
      stub_session(session_data: { verification_user_id: user.id }.merge(return_to_entries))
    end

    context 'for an invite' do
      let!(:member_invite) { create(:project_member, :invited, invite_email: user.email) }

      context 'when onboarding is not available' do
        before do
          get success_signup_identity_verification_path
        end

        context 'when not yet verified' do
          let(:user) { unconfirmed_user }

          it 'redirects back to signup_identity_verification_path' do
            expect(response).to redirect_to(signup_identity_verification_path)
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

          it 'does not update onboarding_status' do
            expect(user.onboarding_status).to eq({})
          end
        end

        it 'renders the template with the after_sign_in_path_for variable', :aggregate_failures do
          expect(response).to have_gitlab_http_status(:ok)
          expect(assigns(:redirect_url)).to eq(stored_user_return_to_path)
        end

        it 'tracks phone_verification_for_low_risk_users registration_completed event', :experiment do
          expect(experiment(:phone_verification_for_low_risk_users))
            .to track(:registration_completed).on_next_instance.with_context(user: user)

          get success_signup_identity_verification_path
        end
      end

      context 'when onboarding is available' do
        before do
          stub_saas_features(onboarding: true)
          user.update!(onboarding_in_progress: true)
        end

        it 'updates the registration types' do
          get success_signup_identity_verification_path

          expect(user.onboarding_status_registration_type).to eq('invite')
          expect(user.onboarding_status_initial_registration_type).to eq('invite')
        end

        it 'sets the tracking_label to invite registration' do
          get success_signup_identity_verification_path

          expect(assigns(:tracking_label)).to eq(::Onboarding::Status::TRACKING_LABEL[:invite])
        end
      end
    end

    context 'for trial registration' do
      before do
        stub_saas_features(onboarding: true)
        user.update!(onboarding_in_progress: true)
      end

      it 'detects a trial' do
        user.update!(onboarding_status_registration_type: 'trial')

        get success_signup_identity_verification_path

        expect(assigns(:tracking_label)).to eq(::Onboarding::Status::TRACKING_LABEL[:trial])
      end
    end
  end

  describe 'GET verify_credit_card' do
    let_it_be(:user) { unconfirmed_user }

    let(:params) { { format: :json } }

    subject(:do_request) { get verify_credit_card_signup_identity_verification_path(params) }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    it_behaves_like 'it verifies presence of credit_card_validation record for the user'
  end

  describe 'POST verify_credit_card_captcha' do
    let_it_be(:user) { unconfirmed_user }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    subject(:do_request) { post verify_credit_card_captcha_signup_identity_verification_path }

    it_behaves_like 'it ensures verification attempt is allowed', 'credit_card' do
      let_it_be(:cc) { create(:credit_card_validation, user: user) }
    end

    it_behaves_like 'it verifies arkose token', 'credit_card'
  end

  describe 'PATCH toggle_phone_exemption' do
    let_it_be(:unconfirmed_user) { create(:user, :unconfirmed, :medium_risk) }
    let_it_be(:user) { unconfirmed_user }

    subject(:do_request) { patch toggle_phone_exemption_signup_identity_verification_path(format: :json) }

    before do
      stub_session(session_data: { verification_user_id: user.id })
    end

    it_behaves_like 'it requires an unconfirmed user'
    it_behaves_like 'it requires a valid verification_user_id'
    it_behaves_like 'toggles phone number verification exemption for the user'
  end
end
