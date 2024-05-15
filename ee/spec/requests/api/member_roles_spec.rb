# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::MemberRoles, api: true, feature_category: :system_access do
  include ApiHelpers
  include AdminModeHelper

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

  before do
    stub_licensed_features(custom_roles: true)
  end

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

  shared_examples "it is available only on self-managed" do
    context "when on SaaS" do
      let(:current_user) { owner }

      before do
        stub_saas_mode
      end

      it "returns 400 error" do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context "when on self-managed", :enable_admin_mode do
      let(:current_user) { admin }

      before do
        stub_self_managed_mode
      end

      it "returns 200" do
        subject

        expect(response).to have_gitlab_http_status(:success)
      end
    end
  end

  shared_examples "it is available only on SaaS" do
    context "when on SaaS" do
      let(:current_user) { owner }

      before do
        stub_saas_mode
      end

      it "returns success" do
        subject

        expect(response).to have_gitlab_http_status(:success)
      end
    end

    context "when on self-managed" do
      let(:current_user) { admin }

      let(:docs_link) do
        Rails.application.routes.url_helpers.help_page_url('ee/update/deprecations.html',
          anchor: 'deprecate-custom-role-creation-for-group-owners-on-self-managed')
      end

      before do
        stub_self_managed_mode
      end

      it "returns 400 error with deprecation message" do
        subject

        expect(response).to have_gitlab_http_status(:bad_request)

        expect(json_response['message']).to eq(
          "400 Bad request - Group-level custom roles are deprecated on self-managed instances. " \
          "See #{docs_link}"
        )
      end
    end
  end

  shared_examples "getting member roles" do
    it_behaves_like "it requires a valid license"

    context "when current user is nil" do
      it "returns unauthorized error" do
        get_member_roles

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "when current user is not authorized" do
      let(:current_user) { user }

      it "returns forbidden error" do
        get_member_roles

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when current user is authorized" do
      let(:current_user) { authorized_user }

      it "returns associated member roles" do
        get_member_roles

        expect(response).to have_gitlab_http_status(:ok)

        expect(json_response).to(match_array(expected_member_roles))
      end
    end
  end

  shared_examples "creating member role" do
    it_behaves_like "it requires a valid license"

    context "when current user is nil" do
      it "returns unauthorized error" do
        create_member_role

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "when current user is unauthorized" do
      let(:current_user) { user }

      it "does not allow less privileged user to add member roles" do
        expect { create_member_role }.not_to change { member_roles.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when current user is authorized" do
      let(:current_user) { authorized_user }

      context "when name param is passed" do
        it "returns the newly created member role", :aggregate_failures do
          expect { create_member_role }.to change { member_roles.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)

          expect(json_response).to include({
            "name" => "Guest + read_code",
            "description" => "My custom guest role",
            "base_access_level" => ::Gitlab::Access::GUEST,
            "read_code" => true,
            "group_id" => group_id
          })
        end
      end

      context "when no name param is passed" do
        before do
          params.delete(:name)
        end

        it "returns newly created member role with a default name", :aggregate_failures do
          expect { create_member_role }.to change { member_roles.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)

          expect(json_response).to include({
            "name" => "Guest - custom",
            "description" => "My custom guest role",
            "base_access_level" => ::Gitlab::Access::GUEST,
            "read_code" => true,
            "group_id" => group_id
          })
        end
      end

      context "when params are missing" do
        let(:params) { { read_code: false } }

        it "returns a 400 error", :aggregate_failures do
          create_member_role

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to match(/base_access_level is missing/)
        end
      end

      context "when params are invalid" do
        let(:params) { { base_access_level: 1 } }

        it "returns a 400 error", :aggregate_failures do
          create_member_role

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
          create_member_role

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('validation error')
        end
      end
    end
  end

  shared_examples "deleting member role" do
    it_behaves_like "it requires a valid license"

    context "when current user is nil" do
      it "returns unauthorized error" do
        delete_member_role

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "when current user is not authorized" do
      let(:current_user) { user }

      it "does not remove the member role" do
        expect { delete_member_role }.not_to change { member_roles.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when current user is authorized" do
      let(:current_user) { authorized_user }

      it "deletes member role", :aggregate_failures do
        expect { delete_member_role }.to change { member_roles.count }.by(-1)

        expect(response).to have_gitlab_http_status(:no_content)
      end

      context "when invalid member role is passed" do
        let(:member_role_id) { 0 }

        it "returns 404 error", :aggregate_failures do
          expect { delete_member_role }.not_to change { member_roles.count }

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
          delete_member_role

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end

  describe "GET /groups/:id/member_roles" do
    subject(:get_member_roles) { get api("/groups/#{group.id}/member_roles", current_user) }

    let(:authorized_user) { owner }
    let(:expected_member_roles) do
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
    end

    before do
      stub_saas_mode
    end

    it_behaves_like "getting member roles"
    it_behaves_like "it is available only on SaaS"

    context "when group does not have any associated member_roles" do
      let(:current_user) { owner }
      let(:group) { group_with_no_member_roles }

      it "returns empty array as response", :aggregate_failures do
        get_member_roles

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to(match([]))
      end
    end
  end

  describe "GET /member_roles" do
    subject(:get_member_roles) { get api("/member_roles", current_user) }

    let(:authorized_user) { admin }
    let(:expected_member_roles) do
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
    end

    before do
      stub_self_managed_mode
      enable_admin_mode!(admin)
    end

    it_behaves_like "getting member roles"
    it_behaves_like "it is available only on self-managed"
  end

  describe "POST /groups/:id/member_roles" do
    subject(:create_member_role) { post api("/groups/#{group.id}/member_roles", current_user), params: params }

    let(:authorized_user) { owner }
    let(:member_roles) { group.member_roles }
    let(:group_id) { group.id }
    let(:params) do
      {
        name: 'Guest + read_code',
        base_access_level: ::Gitlab::Access::GUEST,
        read_code: true,
        description: 'My custom guest role'
      }
    end

    before do
      stub_saas_mode
    end

    it_behaves_like "creating member role"
    it_behaves_like "it is available only on SaaS"

    context "when group is not a root group" do
      let(:group) { create(:group, parent: group_with_member_roles) }
      let(:current_user) { owner }

      it "returns a 400 error", :aggregate_failures do
        create_member_role

        expect(response).to have_gitlab_http_status(:bad_request)

        expect(json_response['message']).to match(/Creation of member role is allowed only for root groups/)
      end
    end
  end

  describe "POST /member_roles" do
    subject(:create_member_role) { post api("/member_roles", current_user), params: params }

    let(:authorized_user) { admin }
    let(:member_roles) { MemberRole }
    let(:group_id) { nil }
    let(:params) do
      {
        name: 'Guest + read_code',
        base_access_level: ::Gitlab::Access::GUEST,
        read_code: true,
        description: 'My custom guest role'
      }
    end

    before do
      stub_self_managed_mode
      enable_admin_mode!(admin)
    end

    it_behaves_like "creating member role"
    it_behaves_like "it is available only on self-managed"
  end

  describe "DELETE /groups/:id/member_roles/:member_role_id" do
    subject(:delete_member_role) { delete api("/groups/#{group.id}/member_roles/#{member_role_id}", current_user) }

    let(:authorized_user) { owner }
    let(:member_roles) { group.member_roles }
    let(:member_role_id) { member_role_1.id }

    before do
      stub_saas_mode
    end

    it_behaves_like "deleting member role"
    it_behaves_like "it is available only on SaaS"
  end

  describe "DELETE /member_roles/:member_role_id" do
    subject(:delete_member_role) { delete api("/member_roles/#{member_role_id}", current_user) }

    let(:authorized_user) { admin }
    let(:member_roles) { MemberRole }
    let(:member_role_id) { instance_member_role.id }

    before do
      stub_self_managed_mode
      enable_admin_mode!(admin)
    end

    it_behaves_like "deleting member role"
    it_behaves_like "it is available only on self-managed"
  end

  private

  def stub_saas_mode
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  def stub_self_managed_mode
    stub_saas_features(gitlab_com_subscriptions: false)
  end
end
