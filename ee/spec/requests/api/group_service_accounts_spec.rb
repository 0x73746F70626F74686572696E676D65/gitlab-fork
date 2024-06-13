# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupServiceAccounts, :aggregate_failures, feature_category: :user_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let(:group) { create(:group, organization: organization) }
  let(:subgroup) { create(:group, :private, parent: group) }
  let(:service_account_user) { create(:user, :service_account) }

  before do
    service_account_user.provisioned_by_group_id = group.id
    service_account_user.save!
  end

  RSpec.shared_examples "service account user deletion" do
    it "marks user for deletion", :sidekiq_inline do
      perform_enqueued_jobs { delete api(path, admin, admin_mode: true) }

      expect(response).to have_gitlab_http_status(:no_content)
      expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin)).to exist
    end

    context "when sole owner of a group" do
      let!(:new_group) { create(:group, owners: service_account_user) }

      context "when hard delete disabled" do
        it "does not mark  user for deletion" do
          perform_enqueued_jobs { delete api(path, admin, admin_mode: true) }
          expect(service_account_user.blocked?).to eq(false)
          expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
            hard_delete: false)).not_to exist
          expect(response).to have_gitlab_http_status(:conflict)
        end
      end

      context "when hard delete enabled" do
        let!(:another_group) { create(:group, owners: service_account_user) }

        it "marks user for deletion and group is deleted", :sidekiq_inline do
          perform_enqueued_jobs do
            delete api("/groups/#{group_id}/service_accounts/#{service_account_user.id}?hard_delete=true", admin,
              admin_mode: true)
          end
          expect(response).to have_gitlab_http_status(:no_content)
          expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
            hard_delete: true)).to exist
          expect(service_account_user.reload.blocked?).to eq(true)
          expect(Group.exists?(another_group.id)).to eq(false)
        end

        context "when there is a subgroup" do
          let(:parent_group) { create(:group) }
          let(:subgroup) { create(:group, parent: parent_group) }

          before do
            parent_group.add_owner(create(:user))
            subgroup.add_owner(user)
          end

          it "marks only user for deletion and group is not deleted", :sidekiq_inline do
            perform_enqueued_jobs do
              delete api("/groups/#{group_id}/service_accounts/#{service_account_user.id}?hard_delete=true", admin,
                admin_mode: true)
            end
            expect(response).to have_gitlab_http_status(:no_content)
            expect(Group.exists?(subgroup.id)).to eq(true)
            expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
              hard_delete: true)).to exist
            expect(service_account_user.reload.blocked?).to eq(true)
          end
        end
      end
    end

    it "fails for unauthenticated user" do
      perform_enqueued_jobs { delete api(path) }
      expect(service_account_user.reload.blocked?).to eq(false)
      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it "returns 404 for non-existing user" do
      perform_enqueued_jobs do
        delete api("/groups/#{group_id}/service_accounts/#{non_existing_record_id}", admin, admin_mode: true)
      end

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 User Not Found')
    end

    it "returns a 400 for invalid ID" do
      perform_enqueued_jobs { delete api("/groups/#{group_id}/service_accounts/ASDF", admin, admin_mode: true) }

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    context "when hard delete disabled" do
      it "moves contributions to the ghost user", :sidekiq_might_not_need_inline do
        perform_enqueued_jobs { delete api(path, admin, admin_mode: true) }

        expect(response).to have_gitlab_http_status(:no_content)
        expect(issue.reload).to be_persisted
        expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
          hard_delete: false)).to exist
        expect(service_account_user.reload.blocked?).to eq(true)
      end
    end

    context "when hard delete enabled" do
      it "removes contributions", :sidekiq_might_not_need_inline do
        perform_enqueued_jobs do
          delete api("/groups/#{group_id}/service_accounts/#{service_account_user.id}?hard_delete=true", admin,
            admin_mode: true)
        end

        expect(response).to have_gitlab_http_status(:no_content)
        expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: admin,
          hard_delete: true)).to exist
      end
    end
  end

  describe "POST /groups/:id/service_accounts" do
    subject(:perform_request) { post api("/groups/#{group_id}/service_accounts", user), params: params }

    let_it_be(:params) { {} }

    context 'when Self-managed' do
      before do
        stub_licensed_features(service_accounts: true)
        allow(License).to receive(:current).and_return(license)
      end

      context 'when the feature is licensed' do
        let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

        context 'when current user is an admin', :enable_admin_mode do
          let_it_be(:user) { create(:admin) }

          context 'when the group exists' do
            let(:group_id) { group.id }

            it "creates user with service_account user type" do
              perform_request

              expect(response).to have_gitlab_http_status(:created)
              expect(json_response.keys).to match_array(%w[id name username])

              user = User.find(json_response['id'])

              expect(user.username).to start_with("service_account_group_#{group_id}")
              expect(user.namespace.organization).to eq(organization)
              expect(user.user_type).to eq('service_account')
            end

            context 'for subgroup' do
              let(:group_id) { subgroup.id }

              it 'returns error' do
                perform_request

                expect(response).to have_gitlab_http_status(:bad_request)
                expect(json_response['message']).to include(
                  s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
                )
              end
            end
          end

          context 'when the group does not exist' do
            let(:group_id) { non_existing_record_id }

            it "returns error" do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end
        end
      end
    end

    context 'when on GitLab.com', :saas do
      before do
        stub_licensed_features(service_accounts: true)
        create(:gitlab_subscription, namespace: group, hosted_plan: hosted_plan)
        stub_application_setting(check_namespace_plan: true)
      end

      context 'when the feature is licensed' do
        let(:hosted_plan) { create(:ultimate_plan) }

        context 'when current user is an owner' do
          before do
            group.add_owner(user)
          end

          context 'when the group exists' do
            let(:group_id) { group.id }

            it "creates user with service_account user type" do
              perform_request

              expect(response).to have_gitlab_http_status(:created)
              expect(json_response.keys).to match_array(%w[id name username])

              user = User.find(json_response['id'])

              expect(user.username).to start_with("service_account_group_#{group_id}")
              expect(user.namespace.organization).to eq(organization)
              expect(user.user_type).to eq('service_account')
            end

            context 'when params are provided' do
              let_it_be(:params) do
                {
                  name: 'John Doe',
                  username: 'test'
                }
              end

              it "creates user with provided details" do
                perform_request

                expect(response).to have_gitlab_http_status(:created)
                expect(json_response['username']).to eq(params[:username])
                expect(json_response['name']).to eq(params[:name])
                expect(json_response.keys).to match_array(%w[id name username])
              end

              context 'when user with the username already exists' do
                before do
                  post api("/groups/#{group_id}/service_accounts", user), params: params
                end

                it 'returns error' do
                  perform_request

                  expect(response).to have_gitlab_http_status(:bad_request)
                  expect(json_response['message']).to include('Username has already been taken')
                end
              end
            end

            it "returns bad request when service returns bad request" do
              allow_next_instance_of(::Namespaces::ServiceAccounts::CreateService) do |service|
                allow(service).to receive(:execute).and_return(
                  ServiceResponse.error(message: message, reason: :bad_request)
                )
              end

              perform_request

              expect(response).to have_gitlab_http_status(:bad_request)
            end

            context 'for subgroup' do
              let(:group_id) { subgroup.id }

              it 'returns error' do
                perform_request

                expect(response).to have_gitlab_http_status(:bad_request)
                expect(json_response['message']).to include(
                  s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
                )
              end
            end
          end

          context 'when the group does not exist' do
            let(:group_id) { non_existing_record_id }

            it "returns error" do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end
        end

        context 'when user is not an owner' do
          let(:group_id) { group.id }

          before do
            group.add_maintainer(user)
          end

          it "returns error" do
            perform_request

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'without authentication' do
          let(:group_id) { group.id }

          it "returns error" do
            post api("/groups/#{group_id}/service_accounts")

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end
      end

      context 'when the feature is not licensed' do
        let(:hosted_plan) { create(:free_plan) }

        let(:group_id) { group.id }

        before do
          group.add_owner(user)
        end

        it "returns error" do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe "GET /groups/:id/service_accounts" do
    let(:group_id) { group.id }
    let(:path) { "/groups/#{group_id}/service_accounts" }
    let(:params) { {} }

    subject(:perform_request) { get api(path, user), params: params }

    before do
      stub_licensed_features(service_accounts: true)
    end

    context 'when request is correct' do
      let(:service_account_user2) { create(:user, :service_account) }
      let(:regular_user) { create(:user) }

      before do
        service_account_user2.provisioned_by_group_id = group.id
        regular_user.provisioned_by_group_id = group.id

        regular_user.save!
        service_account_user2.save!

        group.add_owner(user)
      end

      it 'returns 200 status and service account users list' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)

        expect(response).to match_response_schema('public_api/v4/user/safes')
        expect(json_response.size).to eq(2)

        expect(json_response.pluck("id")).not_to include(regular_user.id)
      end

      context 'when order by is specified' do
        let(:params) { { order_by: "username" } }
        let(:username1) { "Auser" }
        let(:username2) { "Buser" }

        before do
          service_account_user.username = username1
          service_account_user2.username = username2
          service_account_user.save!
        end

        it "returns ordered list by username in desc order" do
          perform_request

          expect(response).to match_response_schema('public_api/v4/user/safes')
          expect(json_response.size).to eq(2)
          expect_paginated_array_response(service_account_user2.id, service_account_user.id)
        end

        context "when sort order_by is specified" do
          let(:params) { { order_by: "username", sort: "asc" } }

          it "follows sorting order" do
            perform_request

            expect(response).to match_response_schema('public_api/v4/user/safes')
            expect(json_response.size).to eq(2)
            expect_paginated_array_response(service_account_user.id, service_account_user2.id)
          end

          it 'does not order by any other column than username and id' do
            get api(path, user), params: { order_by: "name" }

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      it_behaves_like 'an endpoint with keyset pagination', invalid_order: nil do
        let(:first_record) { service_account_user2 }
        let(:second_record) { service_account_user }
        let(:api_call) { api(path, user) }
      end
    end

    context 'when group does not exist' do
      let(:group_id) { non_existing_record_id }

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not group owner' do
      before do
        group.add_maintainer(user)
      end

      it "throws forbidden error" do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /groups/:id/service_accounts/:user_id" do
    let(:issue) { create(:issue, author: service_account_user) }
    let(:group_id) { group.id }
    let(:path) { "/groups/#{group_id}/service_accounts/#{service_account_user.id}" }
    let(:admin) { create(:admin) }

    before do
      stub_licensed_features(service_accounts: true)
    end

    it_behaves_like 'DELETE request permissions for admin mode'

    context 'when self-managed' do
      it_behaves_like "service account user deletion"

      it "is not available for non admin users" do
        perform_enqueued_jobs { delete api(path, user) }

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      context 'when feature is not licensed' do
        let(:group_id) { group.id }

        before do
          stub_licensed_features(service_accounts: false)
          group.add_owner(user)
        end

        it 'returns error' do
          perform_enqueued_jobs { delete api(path, service_account_user) }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when .com', :saas do
      it_behaves_like "service account user deletion"

      it "is available for group owners", :sidekiq_inline do
        group.add_owner(user)

        perform_enqueued_jobs { delete api(path, user) }
        expect(response).to have_gitlab_http_status(:no_content)
        expect(Users::GhostUserMigration.where(user: service_account_user, initiator_user: user)).to exist
      end

      it "is not available to non group owners" do
        group.add_maintainer(user)

        perform_enqueued_jobs { delete api(path, user) }
        expect(response).to have_gitlab_http_status(:forbidden)
      end

      context 'when feature is not licensed' do
        let(:group_id) { group.id }

        before do
          stub_licensed_features(service_accounts: false)
          group.add_owner(user)
        end

        it 'returns error' do
          perform_enqueued_jobs { delete api(path, service_account_user) }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe "POST /groups/:id/service_accounts/:user_id/personal_access_tokens" do
    let(:name) { 'new pat' }
    let(:expires_at) { 3.days.from_now.to_date.to_s }
    let(:scopes) { %w[api read_user] }
    let(:params) { { name: name, scopes: scopes, expires_at: expires_at } }

    subject(:perform_request) do
      post(
        api("/groups/#{group_id}/service_accounts/#{service_account_user.id}/personal_access_tokens", user),
        params: params)
    end

    context 'when the feature is licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when user is an owner' do
        before do
          group.add_owner(user)
        end

        context 'when the group exists' do
          it 'creates personal access token for the user' do
            perform_request

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['name']).to eq(name)
            expect(json_response['scopes']).to eq(scopes)
            expect(json_response['expires_at']).to eq(expires_at)
            expect(json_response['id']).to be_present
            expect(json_response['created_at']).to be_present
            expect(json_response['active']).to be_truthy
            expect(json_response['revoked']).to be_falsey
            expect(json_response['token']).to be_present
          end

          context 'when an error is thrown by the model' do
            let(:group_id) { group.id }
            let(:error_message) { 'error message' }
            let!(:admin_personal_access_token) { create(:personal_access_token, :admin_mode, user: create(:admin)) }

            before do
              allow_next_instance_of(::PersonalAccessTokens::CreateService) do |create_service|
                allow(create_service).to receive(:execute).and_return(
                  ServiceResponse.error(message: error_message)
                )
              end
            end

            it 'returns the error' do
              perform_request

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
              expect(json_response['message']).to eq(error_message)
            end
          end

          context 'when target user does not belong to group' do
            before do
              service_account_user.provisioned_by_group_id = nil
              service_account_user.save!
            end

            it 'returns error' do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when target user is not service accounts' do
            let(:regular_user) { create(:user) }

            before do
              regular_user.provisioned_by_group_id = group.id
              regular_user.save!
            end

            it 'returns bad request error' do
              post api(
                "/groups/#{group_id}/service_accounts/#{regular_user.id}/personal_access_tokens", user
              ), params: params

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end
        end

        context 'when group does not exist' do
          let(:group_id) { non_existing_record_id }

          it "returns error" do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when user is not an owner' do
        before do
          group.add_maintainer(user)
        end

        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'without authentication' do
        it 'returns error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when feature is not licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it 'returns error' do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /personal_access_tokens/:token_id/rotate' do
    let(:token) { create(:personal_access_token, user: service_account_user) }

    subject(:perform_request) do
      post api(
        "/groups/#{group_id}/service_accounts/#{service_account_user.id}/personal_access_tokens/#{token.id}/rotate",
        user
      )
    end

    context 'when the feature is licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: true)
      end

      context 'when user is an owner' do
        before do
          group.add_owner(user)
        end

        context 'when the group exists' do
          it 'revokes the token' do
            perform_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['token']).not_to eq(token.token)
            expect(json_response['expires_at']).to eq((Date.today + 1.week).to_s)
          end

          context 'when service raises an error' do
            let(:error_message) { 'boom!' }

            before do
              allow_next_instance_of(PersonalAccessTokens::RotateService) do |service|
                allow(service).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
              end
            end

            it 'returns error message' do
              perform_request

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to eq("400 Bad request - #{error_message}")
            end
          end

          context 'when token does not exist' do
            let(:invalid_path) do
              # rubocop:disable Layout/LineLength
              "/groups/#{group_id}/service_accounts/#{service_account_user.id}/personal_access_tokens/#{non_existing_record_id}/rotate"
              # rubocop:enable Layout/LineLength
            end

            it 'returns not found' do
              post api(invalid_path, user)

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when token does not belong to service account user' do
            before do
              token.user = create(:user)
              token.save!
            end

            it 'returns bad request' do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when target user does not belong to group' do
            before do
              service_account_user.provisioned_by_group_id = nil
              service_account_user.save!
            end

            it 'returns error' do
              perform_request

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'when target user is not service accounts' do
            let(:regular_user) { create(:user) }

            before do
              regular_user.provisioned_by_group_id = group.id
              regular_user.save!
              token.user = regular_user
              token.save!
            end

            it 'returns bad request error' do
              post api(
                "/groups/#{group_id}/service_accounts/#{regular_user.id}/personal_access_tokens/#{token.id}/rotate",
                user
              )

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end
        end

        context 'when group does not exist' do
          let(:group_id) { non_existing_record_id }

          it "returns error" do
            perform_request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when user is not an owner' do
        it 'throws error' do
          perform_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when the feature is not licensed' do
      let(:group_id) { group.id }

      before do
        stub_licensed_features(service_accounts: false)
        group.add_owner(user)
      end

      it "returns error" do
        perform_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
