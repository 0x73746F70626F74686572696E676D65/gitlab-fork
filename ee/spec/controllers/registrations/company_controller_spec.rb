# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::CompanyController, feature_category: :onboarding do
  let_it_be(:user, reload: true) { create(:user, onboarding_in_progress: true) }

  let(:logged_in) { true }
  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
    sign_in(user) if logged_in
  end

  shared_examples 'user authentication' do
    context 'when not authenticated' do
      let(:logged_in) { false }

      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when authenticated' do
      it { is_expected.to have_gitlab_http_status(:ok) }
    end
  end

  shared_examples 'a dot-com only feature' do
    context 'when onboarding is not available' do
      let(:onboarding_enabled?) { false }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when onboarding is available' do
      it { is_expected.to have_gitlab_http_status(:ok) }
    end
  end

  describe '#new' do
    subject(:get_new) { get :new }

    it_behaves_like 'user authentication'
    it_behaves_like 'a dot-com only feature'

    context 'on render' do
      it { is_expected.to render_template 'layouts/minimal' }
      it { is_expected.to render_template(:new) }

      it 'tracks render event' do
        get_new

        expect_snowplow_event(
          category: described_class.name,
          action: 'render',
          user: user,
          label: 'free_registration'
        )
      end

      context 'when in trial flow' do
        it 'tracks render event' do
          user.update!(onboarding_status_registration_type: 'trial')

          get_new

          expect_snowplow_event(
            category: described_class.name,
            action: 'render',
            user: user,
            label: 'trial_registration'
          )
        end
      end
    end
  end

  describe '#create' do
    using RSpec::Parameterized::TableSyntax

    let(:trial_registration) { 'false' }
    let(:glm_params) do
      {
        glm_source: 'some_source',
        glm_content: 'some_content'
      }
    end

    let(:params) do
      {
        company_name: 'GitLab',
        company_size: '1-99',
        phone_number: '+1 23 456-78-90',
        country: 'US',
        state: 'California',
        website_url: 'gitlab.com'
      }.merge(glm_params)
    end

    subject(:post_create) { post :create, params: params }

    context 'on success' do
      before do
        user.update!(onboarding_status_initial_registration_type: 'free')
      end

      it 'creates trial and redirects to the correct path' do
        expect_next_instance_of(
          GitlabSubscriptions::CreateCompanyLeadService,
          user: user,
          params: ActionController::Parameters.new(params).permit!
        ) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        post :create, params: params

        expect(response).to have_gitlab_http_status(:redirect)
        expect(response).to redirect_to(new_users_sign_up_group_path(glm_params))
      end

      context 'when it is a trial registration' do
        let(:trial_registration) { 'true' }

        before do
          user.update!(
            onboarding_status_registration_type: 'trial', onboarding_status_initial_registration_type: 'trial'
          )
        end

        it 'creates trial lead and redirects to the correct path' do
          expect_next_instance_of(
            GitlabSubscriptions::CreateCompanyLeadService,
            user: user,
            params: ActionController::Parameters.new(params).permit!
          ) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          post :create, params: params
        end

        context 'when driving from the onboarding_status.initial_registration_type' do
          let(:trial_registration) { 'false' }

          before do
            user.update!(onboarding_status_initial_registration_type: 'trial')
          end

          it 'creates trial lead and redirects to the correct path' do
            expect_next_instance_of(
              GitlabSubscriptions::CreateCompanyLeadService,
              user: user,
              params: ActionController::Parameters.new(params).permit!
            ) do |service|
              expect(service).to receive(:execute).and_return(ServiceResponse.success)
            end

            post :create, params: params
          end
        end
      end

      context 'when saving onboarding_status_step_url' do
        let(:path) { new_users_sign_up_group_path(glm_params) }

        before do
          allow_next_instance_of(GitlabSubscriptions::CreateCompanyLeadService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        context 'when user is onboarding' do
          context 'when onboarding feature is available' do
            it 'stores onboarding url' do
              post_create

              expect(user.reset.onboarding_status_step_url).to eq(path)
            end
          end

          context 'when onboarding feature is not available' do
            let(:onboarding_enabled?) { false }

            it 'does not store onboarding url' do
              post_create

              expect(user.reset.onboarding_status_step_url).to be_nil
            end
          end
        end
      end

      context 'with snowplow tracking' do
        before do
          allow_next_instance_of(GitlabSubscriptions::CreateCompanyLeadService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.success)
          end
        end

        it 'tracks successful submission event' do
          post_create

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            user: user,
            label: 'free_registration'
          )
        end

        context 'when in trial flow' do
          it 'tracks successful submission event' do
            user.update!(onboarding_status_registration_type: 'trial')

            post_create

            expect_snowplow_event(
              category: described_class.name,
              action: 'successfully_submitted_form',
              user: user,
              label: 'trial_registration'
            )
          end
        end
      end

      context 'when no entries exist in onboarding_status for registration_types' do
        before do
          user.update!(onboarding_status: {})
        end

        it 'redirects to the next step in the path' do
          expect_next_instance_of(GitlabSubscriptions::CreateCompanyLeadService) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          post :create, params: params

          expect(response).to have_gitlab_http_status(:redirect)
          expect(response).to redirect_to(new_users_sign_up_group_path(glm_params))
        end
      end
    end

    context 'on failure' do
      before do
        allow_next_instance_of(GitlabSubscriptions::CreateCompanyLeadService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
        end
      end

      it 'renders company page :new' do
        post :create, params: params

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(flash[:alert]).to eq('failed')
      end

      context 'with snowplow tracking' do
        it 'does not track successful submission event' do
          post_create

          expect_no_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            user: user,
            label: 'free_registration'
          )
        end

        context 'when in trial flow' do
          it 'tracks successful submission event' do
            post_create

            expect_no_snowplow_event(
              category: described_class.name,
              action: 'successfully_submitted_form',
              user: user,
              label: 'trial_registration'
            )
          end
        end
      end
    end
  end
end
