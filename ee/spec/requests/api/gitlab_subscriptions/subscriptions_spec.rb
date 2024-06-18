# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GitlabSubscriptions::Subscriptions, :aggregate_failures, feature_category: :plan_provisioning do
  let_it_be(:admin) { create(:admin) }

  describe 'POST :id/gitlab_subscription', :saas do
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

  describe 'PUT :id/gitlab_subscription', :saas do
    let_it_be(:premium_plan) { create(:premium_plan) }
    let_it_be(:namespace) { create(:group, name: 'test.test-group.22') }

    let_it_be(:gitlab_subscription) do
      create(:gitlab_subscription, namespace: namespace, start_date: '2018-01-01', end_date: '2019-01-01')
    end

    it_behaves_like 'PUT request permissions for admin mode' do
      let(:path) { "/namespaces/#{namespace.id}/gitlab_subscription" }
      let(:current_user) { admin }
      let(:params) { { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' } }
    end

    context 'when authenticated as a regular user' do
      it 'returns an unauthorized error' do
        user = create(:user)

        put api("/namespaces/#{namespace.id}/gitlab_subscription", user, admin_mode: false), params: { seats: 150 }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as an admin' do
      context 'when namespace is not found' do
        it 'returns a 404 error' do
          put api("/namespaces/#{non_existing_record_id}/gitlab_subscription", admin, admin_mode: true),
            params: { seats: 150 }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when namespace does not have a subscription' do
        let_it_be(:namespace_2) { create(:group) }

        it 'returns a 404 error' do
          put api("/namespaces/#{namespace_2.id}/gitlab_subscription", admin, admin_mode: true), params: { seats: 150 }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when namespace is a project namespace' do
        it 'returns a 404 error' do
          project_namespace = create(:project, namespace: namespace)

          put api("/namespaces/#{project_namespace.id}/gitlab_subscription", admin, admin_mode: true),
            params: { seats: 150 }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when params are invalid' do
        it 'returns a 400 error' do
          put api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: { seats: nil }

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when params are valid' do
        it 'updates the subscription for the group' do
          params = { seats: 150, plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

          put api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(gitlab_subscription.reload.seats).to eq(150)
          expect(gitlab_subscription.max_seats_used).to eq(0)
          expect(gitlab_subscription.plan_name).to eq('premium')
          expect(gitlab_subscription.plan_title).to eq('Premium')
        end

        it 'is successful when using full_path routing' do
          params = { seats: 150, plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

          put api("/namespaces/#{namespace.full_path}/gitlab_subscription", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'does not clear out existing data because of defaults' do
          gitlab_subscription.update!(seats: 20, max_seats_used: 42)

          params = { plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

          put api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(gitlab_subscription.reload).to have_attributes(
            seats: 20,
            max_seats_used: 42
          )
        end

        it 'updates the timestamp when the attributes are the same' do
          expect do
            put api("/namespaces/#{namespace.full_path}/gitlab_subscription", admin, admin_mode: true),
              params: namespace.gitlab_subscription.attributes
          end.to change { gitlab_subscription.reload.updated_at }
        end

        context 'when starting a new term' do
          it 'resets the seat attributes for the subscription' do
            params = { seats: 150, plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

            gitlab_subscription.update!(seats: 20, max_seats_used: 42, seats_owed: 22)

            new_start = gitlab_subscription.end_date + 1.year
            new_end = new_start + 1.year
            new_term_params = params.merge(start_date: new_start, end_date: new_end)

            expect(gitlab_subscription.seats_in_use).to eq 0

            put api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: new_term_params

            expect(response).to have_gitlab_http_status(:ok)
            expect(gitlab_subscription.reload).to have_attributes(
              max_seats_used: 0,
              seats_owed: 0
            )
          end
        end

        context 'when updating the trial expiration date' do
          it 'updates the trial expiration date' do
            date = 30.days.from_now.to_date

            params = { seats: 150, plan_code: 'ultimate', trial_ends_on: date.iso8601 }

            put api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true), params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(gitlab_subscription.reload.trial_ends_on).to eq(date)
          end
        end
      end
    end
  end
end
