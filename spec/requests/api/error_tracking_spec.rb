# frozen_string_literal: true

require 'spec_helper'

describe API::ErrorTracking do
  describe "GET sentry project settings" do
    let(:admin) { create(:admin) }
    let(:project_not_found_message) { "404 Project Not Found" }
    let(:unauthorized_message) { "401 Unauthorized" }
    let(:random_user) { create(:user) }
    let(:project_error_tracking_setting) { create(:project_error_tracking_setting) }
    let(:project) do
      create(:project, :repository, creator: admin,
        namespace: admin.namespace, error_tracking_setting: project_error_tracking_setting)
    end

    context 'when user has permission to view settings' do
      it 'returns 200' do
        get api("/projects/#{project.id}/error_tracking/sentry_project_settings", admin)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response["project_name"]).to eq(project_error_tracking_setting.project_name)
        expect(json_response["sentry_external_url"]).to eq(project_error_tracking_setting.sentry_external_url)
      end
    end

    context 'When user does not own the project' do
      it 'returns 404' do
        get api("/projects/#{project.id}/error_tracking/sentry_project_settings", random_user)
        expect(response).to have_gitlab_http_status(404)
        expect(json_response["message"]).to eq(project_not_found_message)
      end
    end

    context 'When unauthenticated' do
      it 'return 401' do
        get api("/projects/#{project.id}/error_tracking/sentry_project_settings")
        expect(response).to have_gitlab_http_status(401)
        expect(json_response["message"]).to eq(unauthorized_message)
      end
    end
  end
end
