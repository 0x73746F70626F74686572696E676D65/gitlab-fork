# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RegistrationsController, type: :request, feature_category: :system_access do
  include SessionHelpers

  let_it_be(:user_attrs) do
    build_stubbed(:user).slice(:first_name, :last_name, :username, :email, :password)
  end

  before do
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    allow(::Arkose::Settings).to receive(:enabled?).and_return(false)
  end

  describe 'GET #new' do
    let(:params) { { user: user_attrs } }

    subject(:new_user) { get new_user_registration_path, params: params }

    context 'with tracking' do
      it 'tracks page render' do
        new_user

        expect_snowplow_event(
          category: described_class.name,
          action: 'render_registration_page',
          label: 'free_registration'
        )
      end

      context 'when invite' do
        let(:params) { { user: user_attrs, invite_email: 'new@email.com' } }

        it 'tracks page render' do
          new_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'render_registration_page',
            label: 'invite_registration'
          )
        end
      end

      context 'when subscription', :saas, :clean_gitlab_redis_sessions do
        before do
          stub_session(session_data: { user_return_to: new_subscriptions_path })
        end

        it 'tracks successful form submission' do
          new_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'render_registration_page',
            label: 'subscription_registration'
          )
        end
      end
    end
  end

  describe 'POST #create' do
    subject(:create_user) { post user_registration_path, params: { user: user_attrs } }

    it_behaves_like 'creates a user with ArkoseLabs risk band on signup request' do
      let(:registration_path) { user_registration_path }
    end

    describe 'identity verification' do
      before do
        stub_application_setting_enum('email_confirmation_setting', 'hard')
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      context 'when identity verification is turned off' do
        let_it_be(:devise_token) { Devise.friendly_token }

        before do
          allow(Devise).to receive(:friendly_token).and_return(devise_token)
        end

        describe 'sending confirmation instructions' do
          it 'sends Devise confirmation instructions' do
            expect { create_user }.to have_enqueued_mail(DeviseMailer, :confirmation_instructions)
          end

          it 'does not send custom confirmation instructions' do
            expect(::Notify).not_to receive(:confirmation_instructions_email)

            create_user
          end

          it 'sets the confirmation_sent_at time', :freeze_time do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_sent_at).to eq(Time.current)
          end

          it 'sets the confirmation_token to the unencrypted Devise token' do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_token).to eq(devise_token)
          end
        end

        describe 'setting a session variable' do
          it 'does not set the `verification_user_id` session variable' do
            create_user

            expect(request.session.has_key?(:verification_user_id)).to eq(false)
          end
        end

        describe 'redirection' do
          it 'redirects to the `users_almost_there_path`' do
            create_user

            expect(response).to redirect_to(users_almost_there_path(email: user_attrs[:email]))
          end
        end
      end

      context 'when identity verification is available' do
        let_it_be(:custom_token) { '123456' }
        let_it_be(:encrypted_token) { Devise.token_generator.digest(User, user_attrs[:email], custom_token) }

        before do
          stub_saas_features(identity_verification: true)
          allow_next_instance_of(::Users::EmailVerification::GenerateTokenService) do |srvc|
            allow(srvc).to receive(:generate_token).and_return(custom_token)
          end
        end

        describe 'sending confirmation instructions' do
          it 'does not send Devise confirmation instructions' do
            expect { create_user }.not_to have_enqueued_mail(DeviseMailer, :confirmation_instructions)
          end

          it 'sends custom confirmation instructions' do
            expect(::Notify).to receive(:confirmation_instructions_email)
              .with(user_attrs[:email], token: custom_token).once.and_call_original

            create_user
          end

          it 'sets the confirmation_sent_at time', :freeze_time do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_sent_at).to eq(Time.current)
          end

          it 'sets the confirmation_token to the encrypted custom token' do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_token).to eq(encrypted_token)
          end
        end

        describe 'preventing token collisions' do
          it 'does not raise an error when an identical token exists in the database' do
            create_user

            user_attrs = build_stubbed(:user).slice(:first_name, :last_name, :username, :email, :password)

            expect { post user_registration_path, params: { user: user_attrs } }.not_to raise_error
          end
        end

        describe 'setting a session variable' do
          it 'sets the `verification_user_id` session variable' do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(request.session[:verification_user_id]).to eq(user.id)
          end
        end

        describe 'handling sticking' do
          it 'sticks or unsticks the request' do
            allow(User.sticking).to receive(:find_caught_up_replica)

            create_user

            user = User.find_by_username(user_attrs[:username])
            expect(User.sticking)
              .to have_received(:find_caught_up_replica)
              .with(:user, user.id)

            stick_object = request.env[::Gitlab::Database::LoadBalancing::RackMiddleware::STICK_OBJECT].first
            expect(stick_object[0]).to eq(User.sticking)
            expect(stick_object[1]).to eq(:user)
            expect(stick_object[2]).to eq(user.id)
          end
        end

        describe 'redirection' do
          it 'redirects to the `signup_identity_verification_path`' do
            create_user

            expect(response).to redirect_to(signup_identity_verification_path)
          end
        end

        context 'when user is not persisted' do
          before do
            create(:user, email: user_attrs[:email])
          end

          it 'does not try to send custom confirmation instructions' do
            expect_next_instance_of(Users::EmailVerification::SendCustomConfirmationInstructionsService) do |service|
              expect(service).not_to receive(:send_instructions)
            end

            create_user
          end

          it 'tracks registration error' do
            create_user

            expect_snowplow_event(
              category: 'Gitlab::Tracking::Helpers::InvalidUserErrorEvent',
              action: 'track_free_registration_error',
              label: 'email_has_already_been_taken'
            )
          end
        end
      end
    end

    context 'with onboarding progress' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
      end

      context 'when onboarding feature is available' do
        before do
          stub_saas_features(onboarding: true)
        end

        it 'sets onboarding' do
          create_user

          created_user = User.find_by(email: user_attrs[:email])
          expect(created_user.onboarding_in_progress).to be_truthy
        end
      end

      context 'when onboarding feature is not available' do
        it 'does not set onboarding' do
          create_user

          created_user = User.find_by(email: user_attrs[:email])
          expect(created_user.onboarding_in_progress).to be_falsey
        end
      end
    end

    describe 'phone verification service daily transaction limit check' do
      it 'is executed' do
        service = PhoneVerification::Users::RateLimitService
        expect(service).to receive(:assume_user_high_risk_if_daily_limit_exceeded!).with(an_instance_of(User))

        create_user
      end
    end

    describe 'user signup cap' do
      before do
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      context 'when user signup cap is exceeded on an ultimate license' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:new_user_signups_cap).and_return(1)
          create(:group_member, :developer)

          license = create(:license, plan: License::ULTIMATE_PLAN)
          allow(License).to receive(:current).and_return(license)
        end

        it 'sets a new non-billable user state to active' do
          create_user

          user = User.find_by(email: user_attrs[:email])
          expect(user).to be_active
        end
      end
    end

    context 'with tracking' do
      before do
        stub_saas_features(onboarding: true)
      end

      it 'tracks successful form submission' do
        create_user

        expect_snowplow_event(
          category: described_class.name,
          action: 'successfully_submitted_form',
          label: 'free_registration',
          user: User.find_by(email: user_attrs[:email])
        )
      end

      context 'when invite' do
        before do
          # We are doing this here so that invites are accepted as this is a guard for
          # that happening and not a focus of this test in general.
          allow_next_instance_of(User) do |user|
            allow(user).to receive(:active_for_authentication?).and_return(true)
          end

          create(:group_member, :invited, invite_email: user_attrs[:email])
        end

        subject(:create_user) do
          post user_registration_path, params: { user: user_attrs, invite_email: user_attrs[:email] }
        end

        it 'tracks successful form submission' do
          create_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            label: 'invite_registration',
            user: User.find_by(email: user_attrs[:email])
          )
        end
      end

      context 'when subscription', :saas, :clean_gitlab_redis_sessions do
        before do
          stub_session(session_data: { user_return_to: new_subscriptions_path })
        end

        it 'tracks successful form submission' do
          create_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            label: 'subscription_registration',
            user: User.find_by(email: user_attrs[:email])
          )
        end
      end
    end
  end
end
