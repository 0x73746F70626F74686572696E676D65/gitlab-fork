# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ServiceAccounts, :aggregate_failures, feature_category: :user_management do
  let(:user)  { create(:user) }
  let(:admin) { create(:admin) }
  let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

  describe "POST /service_accounts" do
    subject(:perform_request_as_admin) { post api("/service_accounts", admin, admin_mode: true), params: params }

    let_it_be(:params) { {} }

    context 'when feature is licensed' do
      before do
        stub_licensed_features(service_accounts: true)
        allow(License).to receive(:current).and_return(license)
      end

      context 'when user is an admin' do
        it "creates user with user type service_account_user" do
          perform_request_as_admin

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['username']).to start_with('service_account')
        end

        context 'when params are provided' do
          let_it_be(:params) do
            {
              name: 'John Doe',
              username: 'test'
            }
          end

          it "creates user with provided details" do
            perform_request_as_admin

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['username']).to eq(params[:username])
            expect(json_response['name']).to eq(params[:name])
            expect(json_response.keys).to match_array(%w[id name username])
          end

          context 'when user with the username already exists' do
            before do
              post api("/service_accounts", admin, admin_mode: true), params: params
            end

            it 'returns error' do
              perform_request_as_admin

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to include('Username has already been taken')
            end
          end
        end

        it 'returns bad request error when service returns bad request' do
          allow_next_instance_of(::Users::ServiceAccounts::CreateService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: message, reason: :bad_request)
            )
          end

          perform_request_as_admin

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when user is not an admin' do
        it "returns error" do
          post api("/service_accounts", user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when licensed feature is not present' do
      it "returns error" do
        perform_request_as_admin

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "GET /service_accounts" do
    let_it_be(:service_account_buser) { create(:user, :service_account, username: "Buser") }
    let_it_be(:service_account_auser) { create(:user, :service_account, username: "Auser") }
    let_it_be(:regular_user) { create(:user) }
    let(:path) { "/service_accounts" }
    let_it_be(:params) { {} }

    subject(:perform_request) { get api(path, admin, admin_mode: true), params: params }

    context 'when feature is licensed' do
      before do
        stub_licensed_features(service_accounts: true)
        allow(License).to receive(:current).and_return(license)
      end

      context 'when params are empty' do
        before do
          perform_request
        end

        it 'returns 200 status service account users list' do
          expect(response).to have_gitlab_http_status(:ok)

          expect(response).to match_response_schema('public_api/v4/user/safes')
          expect(json_response.size).to eq(2)

          expect_paginated_array_response(service_account_auser.id, service_account_buser.id)
          expect(json_response.pluck("id")).not_to include(regular_user.id)
        end
      end

      context 'when params has order_by specified' do
        context 'when username' do
          let_it_be(:params) { { order_by: "username" } }

          it 'orders by username in desc order' do
            perform_request

            expect_paginated_array_response(service_account_buser.id, service_account_auser.id)
          end

          context 'when sort order is specified' do
            let_it_be(:params) { { order_by: "username", sort: "asc" } }

            it 'follows sort order' do
              perform_request

              expect_paginated_array_response(service_account_auser.id, service_account_buser.id)
            end
          end
        end

        context 'when order_by is neither id or username' do
          let_it_be(:params) { { order_by: "name" } }

          it 'throws error' do
            perform_request

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      it_behaves_like 'an endpoint with keyset pagination', invalid_order: nil do
        let(:first_record) { service_account_auser }
        let(:second_record) { service_account_buser }
        let(:api_call) { api(path, admin, admin_mode: true) }
      end
    end

    context 'when feature is not licensed' do
      it "returns error" do
        get api(path, admin, admin_mode: true), params: {}

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
