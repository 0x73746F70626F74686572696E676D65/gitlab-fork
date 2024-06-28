# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Users, :aggregate_failures, :api, feature_category: :subscription_management do
  describe 'GET /internal/gitlab_subscriptions/users/:id' do
    let_it_be(:user) { create(:user) }
    let(:user_id) { user.id }
    let(:user_path) { "/internal/gitlab_subscriptions/users/#{user_id}" }

    context 'when unauthenticated' do
      it 'returns authentication error' do
        get api(user_path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as user' do
      it 'returns authentication error' do
        get api(user_path, create(:user))

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as admin' do
      let_it_be(:admin) { create(:admin) }

      subject(:get_user) do
        get api(user_path, admin, admin_mode: true)
      end

      it 'returns success' do
        get_user

        expected_attributes = %w[id username name web_url]

        expect(response).to have_gitlab_http_status(:ok)

        expect(json_response["id"]).to eq(user_id)
        expect(json_response.keys).to eq(expected_attributes)
      end

      context 'when user does not exists' do
        let(:user_id) { -1 }

        it 'returns not found' do
          get_user

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq("404 User Not Found")
        end
      end
    end
  end
end
