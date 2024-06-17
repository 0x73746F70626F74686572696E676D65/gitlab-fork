# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GitlabSubscriptions::Subscriptions, :aggregate_failures, feature_category: :plan_provisioning do
  describe 'POST :id/gitlab_subscription', :saas do
    let_it_be(:admin) { create(:admin) }
    let_it_be(:namespace) { create(:namespace) }

    it_behaves_like 'POST request permissions for admin mode' do
      let(:current_user) { admin }
      let(:path) { "/namespaces/#{namespace.id}/gitlab_subscription" }
      let(:params) { { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' } }
    end

    context 'when authenticated as a regular user' do
      it 'returns an unauthorized error' do
        user = create(:user)

        post api("/namespaces/#{namespace.id}/gitlab_subscription", user), params: {}

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as an admin' do
      it 'fails when some start_date is missing' do
        params = { end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' }

        post api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'fails when the record is invalid' do
        params = { start_date: nil, end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' }

        post api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'creates a subscription for the namespace' do
        params = { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' }

        post api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(namespace.gitlab_subscription).to be_present
      end

      it 'sets the trial_starts_on to the start_date' do
        params = { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate', trial: true }

        post api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(namespace.reload.gitlab_subscription.trial_starts_on).to be_present
        expect(namespace.gitlab_subscription.trial_starts_on.iso8601).to eq params[:start_date]
      end

      it 'can create a subscription using full_path' do
        params = { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' }

        post api("/namespaces/#{namespace.full_path}/gitlab_subscription", admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(namespace.gitlab_subscription).to be_present
      end

      context 'when the namespace does not exist' do
        it 'returns a 404' do
          params = { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' }

          post api("/namespaces/#{non_existing_record_id}/gitlab_subscription", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when creating subscription for project namespace' do
        it 'returns a 404' do
          project_namespace = create(:project, namespace: namespace)

          params = { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' }

          post api("/namespaces/#{project_namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end
    end
  end
end
