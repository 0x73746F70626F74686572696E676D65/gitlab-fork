# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TrialRegistrationsController, :saas, feature_category: :onboarding do
  include FullNameHelper

  describe 'GET new' do
    let(:get_params) { {} }

    subject(:get_new) do
      get new_trial_registration_path, params: get_params
      response
    end

    context 'when not on gitlab.com and not in development environment' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when user is not authenticated' do
      it { is_expected.to have_gitlab_http_status(:ok) }

      context 'with tracking' do
        it 'tracks page render' do
          get_new

          expect_snowplow_event(
            category: described_class.name,
            action: 'render_registration_page',
            label: 'trial_registration'
          )
        end
      end
    end

    context 'when user is authenticated' do
      let(:get_params) { { some_param: '_param_' } }

      before do
        sign_in(create(:user))
      end

      it { is_expected.to redirect_to(new_trial_path(get_params)) }
    end
  end

  describe 'POST create' do
    let(:params) { {} }
    let(:user_params) { build_stubbed(:user).slice(:first_name, :last_name, :email, :username, :password) }

    subject(:post_create) do
      post trial_registrations_path, params: params.merge(user: user_params)
      response
    end

    before do
      allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    end

    context 'with onboarding' do
      let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }
      let(:redirect_params) { glm_params.merge(trial: true) }
      let(:new_user_email) { user_params[:email] }
      let(:params) { glm_params }

      before do
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      it 'onboards the user' do
        post_create

        expect(response).to redirect_to(users_sign_up_welcome_path(redirect_params))
        created_user = User.find_by_email(new_user_email)
        expect(created_user).to be_onboarding_in_progress
        expect(created_user.onboarding_status_step_url).to eq(users_sign_up_welcome_path(redirect_params))
        expect(created_user.onboarding_status_initial_registration_type).to eq('trial')
        expect(created_user.onboarding_status_registration_type).to eq('trial')
      end
    end

    context 'when not on gitlab.com and not in development environment' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when on gitlab.com or in dev environment' do
      it { is_expected.to have_gitlab_http_status(:found) }

      it_behaves_like 'creates a user with ArkoseLabs risk band on signup request' do
        let(:user_attrs) { user_params }
        let(:registration_path) { trial_registrations_path }
      end

      context 'with snowplow tracking', :snowplow do
        it 'tracks successful form submission' do
          post_create

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            label: 'trial_registration',
            user: User.find_by(email: user_params[:email])
          )
        end

        context 'with email confirmation' do
          before do
            stub_application_setting(require_admin_approval_after_user_signup: false)
            stub_saas_features(identity_verification: false)
            allow(User).to receive(:allow_unconfirmed_access_for).and_return 0
          end

          context 'when email confirmation settings is set to `soft`' do
            before do
              stub_application_setting_enum('email_confirmation_setting', 'soft')
            end

            it 'does not track an almost there redirect' do
              post_create

              expect_no_snowplow_event(
                category: described_class.name,
                action: 'render',
                user: User.find_by(email: user_params[:email])
              )
            end
          end

          context 'when email confirmation settings is not set to `soft`' do
            before do
              stub_application_setting_enum('email_confirmation_setting', 'hard')
            end

            it 'tracks an almost there redirect' do
              post_create

              expect_snowplow_event(
                category: described_class.name,
                action: 'render',
                user: User.find_by(email: user_params[:email])
              )
            end
          end
        end
      end

      context 'for derivation of name' do
        it 'sets name from first and last name' do
          post_create

          created_user = User.find_by_email(user_params[:email])
          expect(created_user.name).to eq full_name(user_params[:first_name], user_params[:last_name])
        end
      end

      context 'when email confirmation setting is set to hard' do
        before do
          stub_application_setting_enum('email_confirmation_setting', 'hard')
        end

        it 'marks the account as unconfirmed' do
          post_create

          created_user = User.find_by_email(user_params[:email])
          expect(created_user).not_to be_confirmed
        end
      end

      context 'when user params are not provided' do
        subject(:post_create) { post trial_registrations_path }

        it 'raises an error' do
          expect { post_create }.to raise_error(ActionController::ParameterMissing)
        end
      end

      context 'for signup_intent_step_one experiment' do
        let(:experiment) { instance_double(ApplicationExperiment) }

        before do
          allow_next_instance_of(described_class) do |controller|
            allow(controller)
              .to receive(:experiment)
                    .with(:signup_intent_step_one, actor: instance_of(User))
                    .and_return(experiment)
          end
        end

        context 'when signup_intent is not provided' do
          it 'does not tracks signup_intent_step_one experiment event' do
            expect(experiment).not_to receive(:track).with(:submitted_intent)

            post_create
          end
        end

        context 'when signup intent is provided' do
          let(:params) { { user: user_params, signup_intent: "new_team" } }

          it 'tracks signup_intent_step_one experiment events' do
            expect(experiment).to receive(:track).with(:submitted_intent, label: :signup_intent, property: "new_team")

            post_create
          end
        end
      end
    end
  end
end
