# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User with admin_runners custom role", feature_category: :runner do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be_with_reload(:group) { project.group }
  let_it_be(:role) { create(:member_role, :guest, :admin_runners, namespace: project.group) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe Projects::RunnersController do
    let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }

    before do
      sign_in(user)
    end

    it "#index" do
      get project_runners_path(project)

      expect(response).to redirect_to(project_settings_ci_cd_path(project, anchor: 'js-runners-settings'))
    end

    it "#new" do
      get new_project_runner_path(project)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#update" do
      runner = create(:ci_runner, :project, active: true, projects: [project])

      patch project_runner_path(project, runner), params: { runner: { description: "hello world" } }

      expect(response).to redirect_to(project_runner_path(project, runner))
    end

    it "#toggle_shared_runners" do
      post toggle_shared_runners_project_runners_path(project)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#destroy" do
      runner = create(:ci_runner, :project, projects: [project])

      expect_next_instance_of(Ci::Runners::UnregisterRunnerService, runner, user) do |service|
        expect(service).to receive(:execute).once.and_call_original
      end

      delete project_runner_path(project, runner)

      expect(response).to redirect_to(project_runners_path(project))
    end

    it "#pause" do
      runner = create(:ci_runner, :project, active: true, projects: [project])

      post pause_project_runner_path(project, runner)

      expect(response).to redirect_to(project_runners_path(project))
    end
  end

  describe ::Projects::Settings::CiCdController do
    let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }

    before do
      sign_in(user)
    end

    it "#show" do
      get project_settings_ci_cd_path(project)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('CI/CD Settings')
    end
  end

  describe ::Groups::Settings::CiCdController do
    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

    before do
      sign_in(user)
    end

    it "#show" do
      get group_settings_ci_cd_path(group)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('CI/CD Settings')
    end
  end

  describe API::Groups do
    include ApiHelpers

    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

    pending "PUT /groups/:id" do
      put api("/groups/#{group.id}", user), params: {
        shared_runners_setting: 'disabled_and_unoverridable'
      }

      expect(response).to have_gitlab_http_status(:ok)
      expect(group.reload.shared_runners_setting).to eq('disabled_and_unoverridable')
    end
  end

  describe Mutations::Ci::Runner::Create do
    include GraphqlHelpers

    let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }

    it "creates a runner" do
      post_graphql_mutation(graphql_mutation(:runner_create, {
        runner_type: 'PROJECT_TYPE',
        project_id: project.to_global_id
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:runner_create)

      expect(mutation_response).to be_present
      expect(mutation_response['runner']).to be_present
      expect(mutation_response['errors']).to be_empty
    end
  end

  describe Mutations::Ci::NamespaceCiCdSettingsUpdate do
    include GraphqlHelpers

    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

    it "updates the `allow_stale_runner_pruning` setting" do
      post_graphql_mutation(graphql_mutation(:namespace_ci_cd_settings_update, {
        full_path: group.full_path,
        allow_stale_runner_pruning: true
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(fresh_response_data['errors']).to be_blank

      mutation_response = graphql_mutation_response(:namespace_ci_cd_settings_update)
      expect(mutation_response).to be_present
      expect(mutation_response['ciCdSettings']).to be_present
      expect(mutation_response['errors']).to be_empty
    end

    it "does not allow updating settings that are not related to runners" do
      arguments = described_class
        .own_arguments
        .map { |key, _value| key.underscore.to_sym }
        .excluding(:allow_stale_runner_pruning, :full_path)
      expect(arguments).to be_empty
    end
  end
end
