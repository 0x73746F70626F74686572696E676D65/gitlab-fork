# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User with read_runners custom role", feature_category: :runner do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be_with_reload(:group) { project.group }
  let_it_be(:role) { create(:member_role, :guest, :read_runners, namespace: project.group) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe Groups::RunnersController do
    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: group) }

    let_it_be(:runner) do
      create(:ci_runner, :group, groups: [group], registration_type: :authenticated_user)
    end

    before do
      sign_in(user)
    end

    it "#index" do
      get group_runners_path(group)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#show" do
      get group_runners_path(group, runner)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#new" do
      get new_group_runner_path(group)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#register" do
      get register_group_runner_path(group, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#edit" do
      get edit_group_runner_path(group, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#update" do
      put group_runner_path(group, runner), params: {
        runner: {
          description: "example"
        }
      }

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe Projects::RunnersController do
    let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, source: project) }

    before do
      sign_in(user)
    end

    it "#index" do
      get project_runners_path(project)

      expect(response).to redirect_to(project_settings_ci_cd_path(project, anchor: 'js-runners-settings'))
    end

    it "#new" do
      get new_project_runner_path(project)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#update" do
      runner = create(:ci_runner, :project, active: true, projects: [project])

      patch project_runner_path(project, runner), params: { runner: { description: "hello world" } }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#toggle_shared_runners" do
      post toggle_shared_runners_project_runners_path(project)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#register" do
      runner = create(:ci_runner, :project, projects: [project], registration_type: :authenticated_user)

      get register_namespace_project_runner_path(group, project, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#destroy" do
      runner = create(:ci_runner, :project, projects: [project])

      delete project_runner_path(project, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#pause" do
      runner = create(:ci_runner, :project, active: true, projects: [project])

      post pause_project_runner_path(project, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end
