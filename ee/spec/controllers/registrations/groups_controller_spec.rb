# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::GroupsController, feature_category: :onboarding do
  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:experiment) { instance_double(ApplicationExperiment) }
  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
  end

  shared_examples 'finishing onboarding' do
    let_it_be(:url) { '_url_' }
    let_it_be(:onboarding_in_progress) { true }

    let_it_be(:user) do
      create(:user, onboarding_in_progress: onboarding_in_progress) do |record|
        create(:user_detail, user: record, onboarding_status_step_url: url)
      end
    end

    context 'when onboarding feature is not available' do
      let(:onboarding_enabled?) { false }

      it 'does not finish onboarding' do
        subject
        user.reload

        expect(user.onboarding_in_progress).to be(true)
      end
    end

    context 'when onboarding feature is available' do
      it 'finishes onboarding' do
        subject
        user.reload

        expect(user.onboarding_in_progress).to be(false)
      end
    end
  end

  describe 'GET #new' do
    subject(:get_new) { get :new }

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      before do
        sign_in(user)
      end

      context 'when onboarding feature is available' do
        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:new) }

        it 'assigns the group variable to a new Group with the default group visibility', :aggregate_failures do
          get_new

          expect(assigns(:group)).to be_a_new(Group)
          expect(assigns(:group).visibility_level).to eq(Gitlab::CurrentSettings.default_group_visibility)
        end

        it 'builds a project object' do
          get_new

          expect(assigns(:project)).to be_a_new(Project)
        end

        context 'when form is rendered' do
          before do
            allow(controller)
              .to receive(:experiment)
              .with(:project_templates_during_registration, user: user)
              .and_return(experiment)
          end

          it 'tracks the new group view event' do
            expect(experiment).to receive(:publish)
            expect(experiment).to receive(:track).with(:render_groups_new, label: 'free_registration')

            get_new

            expect_snowplow_event(
              category: described_class.name,
              action: 'view_new_group_action',
              label: 'free_registration',
              user: user
            )
          end

          context 'when on trial' do
            before do
              user.update!(onboarding_status_registration_type: 'trial')
            end

            it 'tracks the new group view event' do
              expect(experiment).to receive(:publish)
              expect(experiment).to receive(:track).with(:render_groups_new, label: 'trial_registration')

              get_new

              expect_snowplow_event(
                category: described_class.name,
                action: 'view_new_group_action',
                label: 'trial_registration',
                user: user
              )
            end
          end
        end

        context 'when user does not have the ability to create a group' do
          let(:user) { create(:user, can_create_group: false) }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end

      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      it_behaves_like 'hides email confirmation warning'
    end
  end

  describe 'POST #create' do
    subject(:post_create) { post :create, params: params }

    let(:params) { { group: group_params, project: project_params }.merge(extra_params) }
    let(:extra_params) { {} }
    let(:group_params) do
      {
        name: 'Group name',
        path: 'group-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE.to_s
      }
    end

    let(:project_params) do
      {
        name: 'New project',
        path: 'project-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE,
        template_name: '',
        initialize_with_readme: 'true'
      }
    end

    context 'with an unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'with an authenticated user' do
      before do
        sign_in(user)
      end

      it_behaves_like 'hides email confirmation warning'
      it_behaves_like 'finishing onboarding'

      it 'creates a group and project' do
        expect { post_create }.to change { Group.count }.by(1).and change { Project.count }.by(1)
      end

      it 'sets the cookie for confetti for learn gitlab' do
        post_create

        expect(cookies[:confetti_post_signup]).to eq(true)
      end

      context 'when form is successfully submitted' do
        before do
          allow(controller).to receive(:experiment).and_return(experiment)
        end

        it 'tracks submission event' do
          expect(experiment).to receive(:publish)
          expect(experiment).to receive(:track).with(:successfully_submitted_form, label: 'free_registration')

          expect(experiment).not_to receive(:track).with(
            'select_project_template_plainhtml',
            label: 'free_registration'
          )

          post_create
        end

        context 'with template name' do
          let(:project_params) { super().merge(template_name: 'plainhtml') }

          it 'tracks submission event' do
            expect(experiment).to receive(:publish)
            expect(experiment).to receive(:track).with(:successfully_submitted_form, label: 'free_registration')

            expect(experiment).to receive(:track).with(
              'select_project_template_plainhtml',
              label: 'free_registration'
            )

            post_create
          end
        end

        context 'when on trial' do
          before do
            user.update!(onboarding_status_registration_type: 'trial')
          end

          it 'tracks submission event' do
            expect(experiment).to receive(:publish)
            expect(experiment).to receive(:track).with(:successfully_submitted_form, label: 'trial_registration')

            post_create
          end
        end
      end

      context 'when there is no suggested path based from the name' do
        let(:group_params) { { name: '⛄⛄⛄', path: '' } }

        it 'creates a group' do
          expect { subject }.to change { Group.count }.by(1)
        end
      end

      context 'when the group cannot be created' do
        let(:group_params) { { name: '', path: '' } }

        it 'does not create a group', :aggregate_failures do
          expect { post_create }.not_to change { Group.count }
          expect(assigns(:group).errors).not_to be_blank
        end

        it 'the project is not disregarded completely' do
          post_create

          expect(assigns(:project).name).to eq('New project')
        end

        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:new) }

        context 'when form is not submitted' do
          before do
            allow(controller).to receive(:experiment).and_return(experiment)
          end

          it 'does not track submission event' do
            expect(experiment).to receive(:publish)
            expect(experiment).not_to receive(:track).with(:successfully_submitted_form, label: 'free_registration')

            post_create
          end
        end
      end

      context 'with signup onboarding not enabled' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context "when group can be created but the project can't" do
        let(:project_params) { { name: '', path: '', visibility_level: Gitlab::VisibilityLevel::PRIVATE } }

        it 'does not create a project', :aggregate_failures do
          expect { post_create }.to change { Group.count }
          expect { post_create }.not_to change { Project.count }
          expect(assigns(:project).errors).not_to be_blank
        end

        it { is_expected.to have_gitlab_http_status(:ok) }
        it { is_expected.to render_template(:new) }
      end

      context "when a group is already created but a project isn't" do
        before do
          group.add_owner(user)
        end

        let(:group_params) { { id: group.id } }

        it 'creates a project and not another group', :aggregate_failures do
          expect { post_create }.to change { Project.count }
          expect { post_create }.not_to change { Group.count }
        end
      end

      context 'when redirecting' do
        let_it_be(:project) { create(:project) }

        let(:success_path) { project_learn_gitlab_path(project) }

        before do
          allow_next_instance_of(Registrations::StandardNamespaceCreateService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: { project: project })
            )
          end
        end

        it { is_expected.to redirect_to(success_path) }
      end

      context 'with import_url in the params' do
        let(:params) { { group: group_params, import_url: new_import_github_path } }

        let(:group_params) do
          {
            name: 'Group name',
            path: 'group-path',
            visibility_level: Gitlab::VisibilityLevel::PRIVATE.to_s
          }
        end

        it_behaves_like 'hides email confirmation warning'
        it_behaves_like 'finishing onboarding'

        context "when a group can't be created" do
          before do
            allow_next_instance_of(Registrations::ImportNamespaceCreateService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(message: 'failed', payload: { group: Group.new, project: Project.new })
              )
            end
          end

          it { is_expected.to render_template(:new) }
        end

        context 'when there is no suggested path based from the group name' do
          let(:group_params) { { name: '⛄⛄⛄', path: '' } }

          it 'creates a group, and redirects' do
            expect { post_create }.to change { Group.count }.by(1)
            expect(post_create).to have_gitlab_http_status(:redirect)
          end
        end

        context 'when group can be created' do
          it 'creates a group' do
            expect { post_create }.to change { Group.count }.by(1)
          end

          it 'redirects to the import url with a namespace_id parameter' do
            allow_next_instance_of(Registrations::ImportNamespaceCreateService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.success(payload: { group: group })
              )
            end

            expect(post_create).to redirect_to(new_import_github_url(namespace_id: group.id))
          end
        end
      end
    end
  end
end
