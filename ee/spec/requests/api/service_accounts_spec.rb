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
end
