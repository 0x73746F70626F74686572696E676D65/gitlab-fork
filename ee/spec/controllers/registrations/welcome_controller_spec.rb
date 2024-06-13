# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::WelcomeController, feature_category: :onboarding do
  let_it_be(:user, reload: true) { create(:user, onboarding_in_progress: true) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }

  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
  end

  describe '#show' do
    let(:show_params) { {} }

    subject(:get_show) { get :show, params: show_params }

    context 'without a signed in user' do
      it { is_expected.to redirect_to new_user_registration_path }
    end

    context 'with signed in user' do
      before do
        sign_in(user)
      end

      it { is_expected.to render_template(:show) }

      context 'for signup_intent_step_one experiment' do
        let(:experiment) { instance_double(ApplicationExperiment) }

        it 'tracks experiment events' do
          allow(controller)
            .to receive(:experiment)
                  .with(:signup_intent_step_one, actor: user)
                  .and_return(experiment)

          expect(experiment).to receive(:run)
          expect(experiment).to receive(:track).with(:render_welcome, label: 'free_registration')

          get_show
        end
      end

      it 'tracks render event' do
        get_show

        expect_snowplow_event(
          category: 'registrations:welcome:show',
          action: 'render',
          user: user,
          label: 'free_registration'
        )
      end

      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when in invitation flow' do
        it 'tracks render event' do
          user.update!(onboarding_status_registration_type: 'invite')

          get_show

          expect_snowplow_event(
            category: 'registrations:welcome:show',
            action: 'render',
            user: user,
            label: 'invite_registration'
          )
        end
      end

      context 'when in trial flow' do
        it 'tracks render event' do
          user.update!(onboarding_status_registration_type: 'trial')

          get_show

          expect_snowplow_event(
            category: 'registrations:welcome:show',
            action: 'render',
            user: user,
            label: 'trial_registration'
          )
        end
      end

      context 'when completed welcome step' do
        context 'when setup_for_company is set to true' do
          let_it_be(:user) { create(:user, setup_for_company: true) }

          it 'does not track render event' do
            get_show

            expect_no_snowplow_event(
              category: 'registrations:welcome:show',
              action: 'render',
              user: user,
              label: 'free_registration'
            )
          end
        end

        context 'when setup_for_company is set to false' do
          before do
            user.update!(setup_for_company: false)
            sign_in(user)
          end

          it { is_expected.to redirect_to(dashboard_projects_path) }
        end
      end

      context 'when 2FA is required from group' do
        before do
          user = create(:user, onboarding_in_progress: true, require_two_factor_authentication_from_group: true)
          sign_in(user)
        end

        it 'does not perform a redirect' do
          expect(subject).not_to redirect_to(profile_two_factor_auth_path)
        end
      end

      context 'when welcome step is completed' do
        before do
          user.update!(setup_for_company: true)
        end

        context 'when user is confirmed' do
          before do
            sign_in(user)
          end

          it { is_expected.not_to redirect_to user_session_path }
        end

        context 'when user is not confirmed' do
          before do
            stub_application_setting_enum('email_confirmation_setting', 'hard')

            sign_in(user)

            user.update!(confirmed_at: nil)
          end

          it { is_expected.to redirect_to user_session_path }
        end
      end

      render_views

      it 'has the expected submission url' do
        get_show

        expect(response.body).to include("action=\"#{users_sign_up_welcome_path}\"")
      end
    end
  end

  describe '#update' do
    let(:setup_for_company) { 'false' }
    let(:joining_project) { 'false' }
    let(:extra_params) { {} }
    let(:extra_user_params) { {} }
    let(:update_params) do
      {
        user: {
          role: 'software_developer',
          setup_for_company: setup_for_company,
          registration_objective: 'code_storage'
        }.merge(extra_user_params),
        joining_project: joining_project,
        jobs_to_be_done_other: '_jobs_to_be_done_other_',
        glm_source: 'some_source',
        glm_content: 'some_content'
      }.merge(extra_params)
    end

    subject(:patch_update) { patch :update, params: update_params }

    context 'without a signed in user' do
      it { is_expected.to redirect_to new_user_registration_path }
    end

    context 'with a signed in user' do
      before do
        sign_in(user)
      end

      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'with email updates' do
        context 'when registration_objective field is provided' do
          it 'sets the registration_objective' do
            patch_update

            expect(controller.current_user.registration_objective).to eq('code_storage')
          end
        end
      end

      describe 'redirection' do
        context 'when onboarding is not enabled' do
          before do
            allow_next_instance_of(Onboarding::Status) do |instance|
              allow(instance).to receive(:enabled?).and_return(false)
            end
          end

          it { is_expected.to redirect_to dashboard_projects_path }

          it 'tracks successful submission event' do
            patch_update

            expect_snowplow_event(
              category: 'registrations:welcome:update',
              action: 'successfully_submitted_form',
              user: user,
              label: 'free_registration'
            )
          end

          context 'with joining_project selection' do
            context 'when creating a new project' do
              it 'does not track join a project event' do
                patch_update

                expect_no_snowplow_event(
                  category: 'registrations:welcome:update',
                  action: 'select_button',
                  user: user,
                  label: 'join_a_project'
                )
              end
            end

            context 'when joining a project' do
              let(:joining_project) { 'true' }

              it 'tracks join a project event' do
                patch_update

                expect_snowplow_event(
                  category: 'registrations:welcome:update',
                  action: 'select_button',
                  user: user,
                  label: 'join_a_project'
                )
              end
            end
          end

          context 'when the new user already has any accepted group membership' do
            let!(:member1) { create(:group_member, user: user) }

            it 'redirects to the group page' do
              expect(patch_update).to redirect_to(group_path(member1.source))
            end

            context 'when the new user already has more than 1 accepted group membership' do
              it 'redirects to the most recent membership group page' do
                member2 = create(:group_member, user: user)

                expect(patch_update).to redirect_to(group_path(member2.source))
              end
            end

            context 'when the member has an orphaned source at the time of the welcome' do
              it 'redirects to the project dashboard page' do
                member1.source.delete

                expect(patch_update).to redirect_to(dashboard_projects_path)
              end
            end
          end
        end

        context 'when onboarding is enabled' do
          let_it_be(:user, reload: true) { create(:user, onboarding_in_progress: true) }

          context 'when the new user already has any accepted group membership' do
            let!(:member1) { create(:group_member, user: user) }

            context 'when the member has an orphaned source at the time of the welcome' do
              it 'redirects to the project non invite onboarding flow' do
                member1.source.delete

                expect(patch_update).to redirect_to(new_users_sign_up_group_path)
              end
            end
          end

          context 'when joining_project is "true"' do
            let(:joining_project) { 'true' }

            specify do
              patch_update
              user.reset

              expect(user.onboarding_in_progress).to be(false)
              expect(response).to redirect_to dashboard_projects_path
            end
          end

          context 'when joining_project is "false"' do
            context 'with group and project creation' do
              specify do
                patch_update
                user.reset
                path = new_users_sign_up_group_path

                expect(user.onboarding_in_progress).to be(true)
                expect(response).to redirect_to path
              end
            end
          end

          context 'when eligible for iterable trigger' do
            let(:params) do
              {
                comment: '_jobs_to_be_done_other_',
                jtbd: 'code_storage',
                opt_in: false,
                preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
                product_interaction: 'Personal SaaS Registration',
                provider: 'gitlab',
                role: 'software_developer',
                setup_for_company: false,
                uid: user.id,
                work_email: user.email
              }.stringify_keys
            end

            before do
              allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_iterable)
                                                             .with(params)
                                                             .and_return({ success: true })
            end

            it 'initiates iterable trigger creation', :sidekiq_inline do
              expect(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async).and_call_original

              patch_update
            end
          end

          context 'when not eligible for iterable trigger' do
            before do
              allow_next_instance_of(::Onboarding::Status) do |instance|
                allow(instance).to receive(:eligible_for_iterable_trigger?).and_return(false)
              end
            end

            it 'does not initiate iterable trigger creation' do
              expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

              patch_update
            end
          end

          context 'for email opt_in' do
            using RSpec::Parameterized::TableSyntax

            let(:invite?) { true }
            let(:setup_for_company?) { false }

            before do
              allow_next_instance_of(::Onboarding::Status) do |instance|
                allow(instance).to receive(:invite?).and_return(invite?)
                allow(instance).to receive(:setup_for_company?).and_return(setup_for_company?)
              end
            end

            where(:extra_user_params, :opt_in) do
              { onboarding_status_email_opt_in: 'true' }  | true
              { onboarding_status_email_opt_in: 'false' } | false
              { onboarding_status_email_opt_in: nil }     | false
              { onboarding_status_email_opt_in: '1' }     | true
              { onboarding_status_email_opt_in: '0' }     | false
              { onboarding_status_email_opt_in: '' }      | false
              {}                                          | false
            end

            with_them do
              context 'for an invite' do
                specify do
                  patch_update
                  user.reset

                  expect(user.onboarding_status_email_opt_in).to eq(false)
                end
              end

              context 'for a non-invite' do
                let(:invite?) { false }

                context 'when setup_for_company is true' do
                  let(:setup_for_company?) { true }

                  specify do
                    patch_update
                    user.reset

                    expect(user.onboarding_status_email_opt_in).to eq(true)
                  end
                end

                context 'when setup_for_company is false' do
                  specify do
                    patch_update
                    user.reset

                    expect(user.onboarding_status_email_opt_in).to eq(opt_in)
                  end
                end
              end
            end
          end

          context 'when setup_for_company is "true"' do
            let(:setup_for_company) { 'true' }
            let(:trial_concerns) { {} }
            let(:redirect_path) { new_users_sign_up_company_path(expected_params) }
            let(:expected_params) do
              {
                registration_objective: 'code_storage',
                role: 'software_developer',
                jobs_to_be_done_other: '_jobs_to_be_done_other_',
                glm_source: 'some_source',
                glm_content: 'some_content'
              }
            end

            context 'when it is a trial registration' do
              before do
                user.update!(
                  onboarding_status_initial_registration_type: 'trial', onboarding_status_registration_type: 'trial'
                )
              end

              it 'redirects to the company path and stores the url' do
                patch_update
                user.reset

                expect(user.onboarding_in_progress).to be(true)
                expect(user.onboarding_status_step_url).to eq(redirect_path)
                expect(user.onboarding_status_email_opt_in).to eq(true)
                expect(user.onboarding_status_registration_type)
                  .to eq(::Onboarding::StatusCreateService::REGISTRATION_TYPE[:trial])
                expect(response).to redirect_to redirect_path
              end
            end

            context 'when it is not a trial registration' do
              before do
                user.update!(onboarding_status_initial_registration_type: 'free')
              end

              it 'redirects to the company path and stores the url' do
                patch_update
                user.reset

                expect(user.onboarding_in_progress).to be(true)
                expect(user.onboarding_status_step_url).to eq(redirect_path)
                expect(user.onboarding_status_email_opt_in).to eq(true)
                expect(user.onboarding_status_registration_type)
                  .to eq(::Onboarding::StatusCreateService::REGISTRATION_TYPE[:trial])
                expect(response).to redirect_to redirect_path
              end
            end

            context 'when user is an invite registration' do
              it 'does not convert to a trial' do
                user.update!(onboarding_status_registration_type: 'invite')

                patch_update
                user.reset

                expect(user.onboarding_status_registration_type)
                  .not_to eq(::Onboarding::Status::REGISTRATION_TYPE[:trial])
              end
            end

            context 'when user is a subscription registration' do
              context 'when detected from onboarding_status' do
                before do
                  user.update!(onboarding_status_registration_type: 'subscription')
                end

                it 'does not convert to a trial' do
                  patch_update
                  user.reset

                  expect(user.onboarding_status_registration_type)
                    .not_to eq(::Onboarding::Status::REGISTRATION_TYPE[:trial])
                end
              end
            end
          end

          context 'when setup_for_company is "false"' do
            let(:setup_for_company) { 'false' }

            specify do
              patch_update
              user.reset
              path = new_users_sign_up_group_path

              expect(user.onboarding_in_progress).to be(true)
              expect(user.onboarding_status_step_url).to eq(path)
              expect(user.onboarding_status_registration_type)
                .not_to eq(::Onboarding::StatusCreateService::REGISTRATION_TYPE[:trial])
              expect(response).to redirect_to path
            end

            context 'when it is a trial registration' do
              using RSpec::Parameterized::TableSyntax

              context 'when trial detected via onboarding_status' do
                before do
                  user.update!(
                    onboarding_status_initial_registration_type: 'trial', onboarding_status_registration_type: 'trial'
                  )
                end

                where(:extra_user_params, :opt_in) do
                  { onboarding_status_email_opt_in: 'true' }  | true
                  { onboarding_status_email_opt_in: 'false' } | false
                  { onboarding_status_email_opt_in: nil }     | false
                  { onboarding_status_email_opt_in: '1' }     | true
                  { onboarding_status_email_opt_in: '0' }     | false
                  { onboarding_status_email_opt_in: '' }      | false
                  {}                                          | false
                end

                with_them do
                  specify do
                    expected_params = {
                      registration_objective: 'code_storage',
                      role: 'software_developer',
                      jobs_to_be_done_other: '_jobs_to_be_done_other_',
                      glm_source: 'some_source',
                      glm_content: 'some_content'
                    }

                    patch_update
                    user.reset
                    path = new_users_sign_up_company_path(expected_params)

                    expect(user.onboarding_in_progress).to be(true)
                    expect(user.onboarding_status_step_url).to eq(path)
                    expect(user.onboarding_status_email_opt_in).to eq(opt_in)
                    expect(response).to redirect_to path
                  end
                end
              end
            end

            context 'when it is not a trial' do
              let(:expected_params) do
                {
                  registration_objective: 'code_storage',
                  role: 'software_developer',
                  jobs_to_be_done_other: '_jobs_to_be_done_other_',
                  glm_source: 'some_source',
                  glm_content: 'some_content'
                }
              end

              specify do
                patch_update
                user.reset
                path = new_users_sign_up_group_path

                expect(user.onboarding_in_progress).to be(true)
                expect(user.onboarding_status_step_url).to eq(path)
                expect(response).to redirect_to path
              end
            end
          end

          context 'when in subscription flow' do
            before do
              user.update!(onboarding_status_registration_type: 'subscription')
            end

            subject { patch :update, params: update_params }

            it { is_expected.not_to redirect_to new_users_sign_up_group_path }
          end

          context 'when in invitation flow' do
            before do
              user.update!(onboarding_status_registration_type: 'invite')
            end

            it { is_expected.not_to redirect_to new_users_sign_up_group_path }

            it 'tracks successful submission event' do
              patch_update

              expect_snowplow_event(
                category: 'registrations:welcome:update',
                action: 'successfully_submitted_form',
                user: user,
                label: 'invite_registration'
              )
            end
          end

          context 'when in trial flow' do
            before do
              user.update!(onboarding_status_registration_type: 'trial')
            end

            it { is_expected.not_to redirect_to new_users_sign_up_group_path }

            it 'tracks successful submission event' do
              patch_update

              expect_snowplow_event(
                category: 'registrations:welcome:update',
                action: 'successfully_submitted_form',
                user: user,
                label: 'trial_registration'
              )
            end
          end
        end

        context 'when failed request' do
          subject(:patch_update) do
            patch :update, params: { user: { role: 'software_developer' }, joining_project: 'true' }
          end

          before do
            allow_next_instance_of(::Users::SignupService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
            end
          end

          it 'does not track submission event' do
            patch_update

            expect_no_snowplow_event(
              category: 'registrations:welcome:update',
              action: 'successfully_submitted_form',
              user: user,
              label: 'free_registration'
            )
          end

          it 'does not track join a project event' do
            patch_update

            expect_no_snowplow_event(
              category: 'registrations:welcome:update',
              action: 'select_button',
              user: user,
              label: 'join_a_project'
            )
          end
        end
      end
    end
  end
end
