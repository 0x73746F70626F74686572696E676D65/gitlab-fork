# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Subscriptions, :aggregate_failures, :api, feature_category: :plan_provisioning do
  describe 'GET /internal/gitlab_subscriptions/namespaces/:id/gitlab_subscription', :saas do
    let_it_be(:admin) { create(:admin) }
    let_it_be(:namespace) { create(:group) }

    def subscription_path(namespace_id)
      "/internal/gitlab_subscriptions/namespaces/#{namespace_id}/gitlab_subscription"
    end

    context 'when unauthenticated' do
      it 'returns an error response' do
        get api(subscription_path(namespace.id))

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when the user is not an admin' do
      it 'returns an error response' do
        user = create(:user)

        get api(subscription_path(namespace.id), user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the admin is not in admin mode' do
      it 'returns an error response' do
        get api(subscription_path(namespace.id), admin, admin_mode: false)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the namespace cannot be found' do
      it 'returns an error response' do
        get api(subscription_path(non_existing_record_id), admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the namespace does not have a subscription' do
      it 'returns an empty response' do
        get api(subscription_path(namespace.id), admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to match_array(%w[plan usage billing])

        expect(json_response['plan']).to eq(
          'name' => nil,
          'code' => nil,
          'auto_renew' => nil,
          'trial' => nil,
          'upgradable' => nil,
          'exclude_guests' => nil
        )

        expect(json_response['usage']).to eq(
          'max_seats_used' => nil,
          'seats_in_subscription' => nil,
          'seats_in_use' => nil,
          'seats_owed' => nil
        )

        expect(json_response['billing']).to eq(
          'subscription_start_date' => nil,
          'subscription_end_date' => nil,
          'trial_ends_on' => nil
        )
      end
    end

    context 'when the request is authenticated for a namespace with a subscription' do
      it 'returns the subscription data' do
        subscription = create(
          :gitlab_subscription,
          :ultimate,
          namespace: namespace,
          auto_renew: true,
          max_seats_used: 5
        )

        get api(subscription_path(namespace.id), admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to match_array(%w[plan usage billing])

        expect(json_response['plan']).to eq(
          'name' => 'Ultimate',
          'code' => 'ultimate',
          'auto_renew' => true,
          'trial' => false,
          'upgradable' => false,
          'exclude_guests' => true
        )

        expect(json_response['usage']).to eq(
          'max_seats_used' => 5,
          'seats_in_subscription' => 10,
          'seats_in_use' => 0,
          'seats_owed' => 0
        )

        expect(json_response['billing']).to eq(
          'subscription_start_date' => subscription.start_date.iso8601,
          'subscription_end_date' => subscription.end_date.iso8601,
          'trial_ends_on' => nil
        )
      end
    end
  end
end
