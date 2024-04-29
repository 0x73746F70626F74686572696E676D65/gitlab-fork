# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::MemberRoles, api: true, feature_category: :system_access do
  include ApiHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:user) { create(:user) }

  let_it_be(:group_with_member_roles) { create(:group, owners: owner) }
  let_it_be(:group_with_no_member_roles) { create(:group, owners: owner) }

  let_it_be(:member_role_1) { create(:member_role, :read_dependency, namespace: group_with_member_roles) }
  let_it_be(:member_role_2) { create(:member_role, :read_code, namespace: group_with_member_roles) }

  let_it_be(:instance_member_role) { create(:member_role, :read_code, :instance) }

  let(:group) { group_with_member_roles }
  let(:current_user) { nil }

  shared_examples "it requires a valid license" do
    context "when licensed feature is unavailable" do
      let(:current_user) { owner }

      before do
        stub_licensed_features(custom_roles: false)
      end

      it "returns forbidden error" do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "GET /groups/:id/member_roles" do
    subject(:get_group_member_roles) { get api("/groups/#{group.id}/member_roles", current_user) }

    it_behaves_like "it requires a valid license"

    context "when licensed feature is available" do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context "when current user is nil" do
        it "returns forbidden error" do
          get_group_member_roles

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when current user is not the group owner" do
        let(:current_user) { user }

        it "returns forbidden error" do
          get_group_member_roles

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context "when current user is the group owner" do
        let(:current_user) { owner }

        it "returns associated member roles" do
          get_group_member_roles

          expect(response).to have_gitlab_http_status(:ok)

          expect(json_response).to(
            match_array(
              [
                hash_including(
                  "id" => member_role_1.id,
                  "name" => member_role_1.name,
                  "description" => member_role_1.description,
                  "base_access_level" => ::Gitlab::Access::DEVELOPER,
                  "read_dependency" => true,
                  "group_id" => group.id
                ),
                hash_including(
                  "id" => member_role_2.id,
                  "name" => member_role_2.name,
                  "description" => member_role_2.description,
                  "base_access_level" => ::Gitlab::Access::DEVELOPER,
                  "read_code" => true,
                  "group_id" => group.id
                )
              ]
            )
          )
        end

        context "when group does not have any associated member_roles" do
          let(:group) { group_with_no_member_roles }

          it "returns empty array as response", :aggregate_failures do
            get_group_member_roles

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to(match([]))
          end
        end
      end
    end
  end

  describe "GET /member_roles" do
    subject(:get_instance_member_roles) { get api("/member_roles", current_user) }

    it_behaves_like "it requires a valid license"

    context "when licensed feature is available" do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context "when current user is nil" do
        it "returns forbidden error" do
          get_instance_member_roles

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when current user is not the instance admin" do
        let(:current_user) { user }

        it "returns forbidden error" do
          get_instance_member_roles

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context "when current user is the instance admin", :enable_admin_mode do
        let(:current_user) { admin }

        it "returns instance-level member roles" do
          get_instance_member_roles

          expect(response).to have_gitlab_http_status(:ok)

          expect(json_response).to(
            match_array(
              [
                hash_including(
                  "id" => instance_member_role.id,
                  "name" => instance_member_role.name,
                  "description" => instance_member_role.description,
                  "base_access_level" => ::Gitlab::Access::DEVELOPER,
                  "read_code" => true,
                  "group_id" => nil
                )
              ]
            )
          )
        end
      end
    end
  end

  describe "POST /groups/:id/member_roles" do
    let_it_be(:params) do
      {
        base_access_level: ::Gitlab::Access::GUEST,
        read_code: true,
        name: 'Guest + read_code',
        description: 'My custom guest role'
      }
    end

    subject(:create_group_member_role) { post api("/groups/#{group.id}/member_roles", current_user), params: params }

    it_behaves_like "it requires a valid license"

    context "when licensed feature is available" do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context "when on SaaS", :saas do
        context "when current user is nil" do
          it "returns unauthorized error" do
            create_group_member_role

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end

        context "when current user is not the group owner" do
          let(:current_user) { user }

          it "does not allow less privileged user to add member roles" do
            expect { create_group_member_role }.not_to change { group.member_roles.count }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context "when current user is the group owner" do
          let(:current_user) { owner }

          it "returns the newly created member role", :aggregate_failures do
            expect { create_group_member_role }.to change { group.member_roles.count }.by(1)

            expect(response).to have_gitlab_http_status(:created)

            expect(json_response).to include({
              "name" => "Guest + read_code",
              "description" => "My custom guest role",
              "base_access_level" => ::Gitlab::Access::GUEST,
              "read_code" => true,
              "group_id" => group.id
            })
          end

          context "when no name param is passed" do
            let_it_be(:params) do
              {
                base_access_level: ::Gitlab::Access::GUEST,
                read_code: true,
                name: nil,
                description: 'My custom guest role'
              }
            end

            it "returns newly created member role with a default name", :aggregate_failures do
              expect { create_group_member_role }.to change { group.member_roles.count }.by(1)

              expect(response).to have_gitlab_http_status(:created)

              expect(json_response).to include({
                "name" => "Guest - custom",
                "description" => "My custom guest role",
                "base_access_level" => ::Gitlab::Access::GUEST,
                "read_code" => true,
                "group_id" => group.id
              })
            end
          end

          context "when params are missing" do
            let(:params) { { read_code: false } }

            it "returns a 400 error", :aggregate_failures do
              create_group_member_role

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['error']).to match(/base_access_level is missing/)
            end
          end

          context "when params are invalid" do
            let(:params) { { base_access_level: 1 } }

            it "returns a 400 error", :aggregate_failures do
              create_group_member_role

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['error']).to match(/base_access_level does not have a valid value/)
            end
          end

          context 'when group is not a root group' do
            let_it_be(:sub_group) { create :group, parent: group_with_member_roles }
            let(:group) { sub_group }

            it "returns a 400 error", :aggregate_failures do
              create_group_member_role

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to match(/Creation of member role is allowed only for root groups/)
            end
          end

          context "when there are validation errors" do
            before do
              allow_next_instance_of(MemberRole) do |instance|
                instance.errors.add(:base, 'validation error')

                allow(instance).to receive(:valid?).and_return(false)
              end
            end

            it "returns a 400 error with an error message", :aggregate_failures do
              create_group_member_role

              expect(response).to have_gitlab_http_status(:bad_request)
              expect(json_response['message']).to eq('validation error')
            end
          end
        end
      end

      context "when on self-managed" do
        let(:current_user) { user }

        it "returns forbidden error" do
          create_group_member_role

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe "POST /member_roles" do
    let_it_be(:params) do
      {
        base_access_level: ::Gitlab::Access::GUEST,
        read_code: true,
        name: 'Guest + read_code',
        description: 'My custom guest role'
      }
    end

    subject(:create_instance_member_role) { post api("/member_roles", current_user), params: params }

    it_behaves_like "it requires a valid license"

    context "when licensed feature is available" do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context "when current user is nil" do
        it "returns unauthorized error" do
          create_instance_member_role

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when current user is not the instance admin" do
        let(:current_user) { user }

        it "does not allow less privileged user to add member roles" do
          expect { create_instance_member_role }.not_to change { MemberRole.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context "when current user is the instance admin", :enable_admin_mode do
        let(:current_user) { admin }

        it "returns the newly created member role", :aggregate_failures do
          expect { create_instance_member_role }.to change { MemberRole.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)

          expect(json_response).to include({
            "name" => "Guest + read_code",
            "description" => "My custom guest role",
            "base_access_level" => ::Gitlab::Access::GUEST,
            "read_code" => true,
            "group_id" => nil
          })
        end

        context "when no name param is passed" do
          let_it_be(:params) do
            {
              base_access_level: ::Gitlab::Access::GUEST,
              read_code: true,
              name: nil,
              description: 'My custom guest role'
            }
          end

          it "returns newly created member role with a default name", :aggregate_failures do
            expect { create_instance_member_role }.to change { MemberRole.count }.by(1)

            expect(response).to have_gitlab_http_status(:created)

            expect(json_response).to include({
              "name" => "Guest - custom",
              "description" => "My custom guest role",
              "base_access_level" => ::Gitlab::Access::GUEST,
              "read_code" => true,
              "group_id" => nil
            })
          end
        end

        context "when params are missing" do
          let(:params) { { read_code: false } }

          it "returns a 400 error", :aggregate_failures do
            create_instance_member_role

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to match(/base_access_level is missing/)
          end
        end

        context "when params are invalid" do
          let(:params) { { base_access_level: 1 } }

          it "returns a 400 error", :aggregate_failures do
            create_instance_member_role

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to match(/base_access_level does not have a valid value/)
          end
        end

        context "when there are validation errors" do
          before do
            allow_next_instance_of(MemberRole) do |instance|
              instance.errors.add(:base, 'validation error')

              allow(instance).to receive(:valid?).and_return(false)
            end
          end

          it "returns a 400 error with an error message", :aggregate_failures do
            create_instance_member_role

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('validation error')
          end
        end
      end
    end
  end

  describe "DELETE /groups/:id/member_roles/:member_role_id" do
    let_it_be(:member_role_id) { member_role_1.id }

    subject(:delete_group_member_role) do
      delete api("/groups/#{group.id}/member_roles/#{member_role_id}", current_user)
    end

    it_behaves_like "it requires a valid license"

    context "when licensed feature is available" do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context "when current user is nil" do
        it "returns unauthorized error" do
          delete_group_member_role

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when current user is not the group owner" do
        let(:current_user) { user }

        it "does not remove the member role" do
          expect { delete_group_member_role }.not_to change { group.member_roles.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context "when current user is the group owner" do
        let(:current_user) { owner }

        it "removes member role", :aggregate_failures do
          expect { delete_group_member_role }.to change { group.member_roles.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end

        context "when invalid member role is passed" do
          let(:member_role_id) { (member_role_1.id + 10) }

          it "returns 404 if SAML group can not used for a SAML group link", :aggregate_failures do
            expect { delete_group_member_role }.not_to change { group_with_member_roles.member_roles.count }

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['message']).to eq('404 Member Role Not Found')
          end
        end

        context "when there is an error deleting the role" do
          before do
            allow_next_instance_of(::MemberRoles::DeleteService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error'))
            end
          end

          it "returns 400 error" do
            delete_group_member_role

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end
    end
  end

  describe "DELETE /member_roles/:member_role_id" do
    let_it_be(:member_role_id) { instance_member_role.id }

    subject(:delete_instance_member_role) { delete api("/member_roles/#{member_role_id}", current_user) }

    it_behaves_like "it requires a valid license"

    context "when licensed feature is available" do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context "when current user is nil" do
        it "returns unauthorized error" do
          delete_instance_member_role

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when current user is not the instance admin" do
        let(:current_user) { user }

        it "does not remove the member role" do
          expect { delete_instance_member_role }.not_to change { MemberRole.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context "when current user is the instance admin", :enable_admin_mode do
        let(:current_user) { admin }

        it "removes member role", :aggregate_failures do
          expect { delete_instance_member_role }.to change { MemberRole.count }.by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end

        context "when invalid member role is passed" do
          let(:member_role_id) { (member_role_1.id + 10) }

          it "returns 404 if SAML group can not used for a SAML group link", :aggregate_failures do
            expect { delete_instance_member_role }.not_to change { MemberRole.count }

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['message']).to eq('404 Member Role Not Found')
          end
        end

        context "when there is an error deleting the role" do
          before do
            allow_next_instance_of(::MemberRoles::DeleteService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error'))
            end
          end

          it "returns 400 error" do
            delete_instance_member_role

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end
    end
  end
end
