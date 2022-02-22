# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupsController do
  include ExternalAuthorizationServiceHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }
  let_it_be(:subgroup2) { create(:group, :private, parent: subgroup) }

  describe 'GET #show' do
    let(:namespace) { group }

    subject { get :show, params: { id: group.to_param } }

    before do
      namespace.add_owner(user)

      sign_in(user)
    end

    it_behaves_like 'namespace storage limit alert'

    it_behaves_like 'seat count alert'
  end

  describe 'GET #activity' do
    render_views

    let_it_be(:event1) { create(:event, project: project) }
    let_it_be(:event2) { create(:event, :epic_create_event, group: group) }
    let_it_be(:event3) { create(:event, :epic_create_event, group: subgroup) }
    let_it_be(:event4) { create(:event, :epic_create_event, group: subgroup2) }

    context 'when authorized' do
      before do
        group.add_owner(user)
        subgroup.add_owner(user)
        subgroup2.add_owner(user)
        sign_in(user)
      end

      context 'when group events are available' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'includes events from group and subgroups' do
          get :activity, params: { id: group.to_param }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['count']).to eq(4)
        end
      end

      context 'when group events are not available' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'does not include events from group and subgroups' do
          get :activity, params: { id: group.to_param }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['count']).to eq(1)
        end
      end
    end

    context 'when unauthorized' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'includes only events visible to user' do
        get :activity, params: { id: group.to_param }, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['count']).to eq(2)
      end
    end
  end

  describe 'POST #restore' do
    let_it_be(:group) do
      create(:group_with_deletion_schedule,
        marked_for_deletion_on: 1.day.ago,
        deleting_user: user)
    end

    subject { post :restore, params: { group_id: group.to_param } }

    before do
      group.add_owner(user)
    end

    context 'when authenticated user can admin the group' do
      before do
        sign_in(user)
      end

      context 'delayed deletion feature is available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
        end

        context 'success' do
          it 'restores the group' do
            expect { subject }.to change { group.reload.marked_for_deletion? }.from(true).to(false)
          end

          it 'renders success notice upon restoring' do
            subject

            expect(response).to redirect_to(edit_group_path(group))
            expect(flash[:notice]).to include "Group '#{group.name}' has been successfully restored."
          end
        end

        context 'failure' do
          before do
            allow(::Groups::RestoreService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: 'error' })
          end

          it 'does not restore the group' do
            expect { subject }.not_to change { group.reload.marked_for_deletion? }.from(true)
          end

          it 'redirects to group edit page' do
            subject

            expect(response).to redirect_to(edit_group_path(group))
            expect(flash[:alert]).to include 'error'
          end
        end
      end

      context 'delayed deletion feature is not available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
        end

        it 'returns 404' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when authenticated user cannot admin the group' do
      before do
        sign_in(create(:user))
      end

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: group.to_param } }

    before do
      group.add_owner(user)
    end

    context 'when authenticated user can admin the group' do
      before do
        sign_in(user)
      end

      context 'delayed deletion feature is available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
        end

        context 'success' do
          it 'marks the group for delayed deletion' do
            expect { subject }.to change { group.reload.marked_for_deletion? }.from(false).to(true)
          end

          it 'does not immediately delete the group' do
            Sidekiq::Testing.fake! do
              expect { subject }.not_to change(GroupDestroyWorker.jobs, :size)
            end
          end

          it 'redirects to group path with notice about delayed deletion' do
            subject

            expect(response).to redirect_to(group_path(group))
            expect(flash[:notice]).to include "'#{group.name}' has been scheduled for removal on"
          end
        end

        context 'failure' do
          before do
            allow(::Groups::MarkForDeletionService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: 'error' })
          end

          it 'does not mark the group for deletion' do
            expect { subject }.not_to change { group.reload.marked_for_deletion? }.from(false)
          end

          it 'redirects to group edit page' do
            subject

            expect(response).to redirect_to(edit_group_path(group))
            expect(flash[:alert]).to include 'error'
          end
        end

        context 'when group is already marked for deletion' do
          before do
            create(:group_deletion_schedule, group: group, marked_for_deletion_on: Date.current)
          end

          context 'when permanently_remove param is set' do
            it 'deletes the group immediately' do
              expect(GroupDestroyWorker).to receive(:perform_async)

              delete :destroy, params: { id: group.to_param, permanently_remove: true }

              expect(response).to redirect_to(root_path)
              expect(flash[:alert]).to include "Group '#{group.name}' was scheduled for deletion."
            end
          end

          context 'when permanently_remove param is not set' do
            it 'does nothing' do
              subject

              expect(response).to redirect_to(edit_group_path(group))
              expect(flash[:alert]).to include "Group has been already marked for deletion"
            end
          end
        end
      end

      context 'delayed deletion feature is not available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
        end

        it 'immediately schedules a group destroy' do
          Sidekiq::Testing.fake! do
            expect { subject }.to change(GroupDestroyWorker.jobs, :size).by(1)
          end
        end

        it 'redirects to root page with alert about immediate deletion' do
          subject

          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to include "Group '#{group.name}' was scheduled for deletion."
        end
      end
    end

    context 'when authenticated user cannot admin the group' do
      before do
        sign_in(create(:user))
      end

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:group_params) { { name: 'new_group', path: 'new_group' } }

    subject { post :create, params: { group: group_params } }

    context 'authorization' do
      it 'allows an auditor with "can_create_group" set to true to create a group' do
        sign_in(create(:user, :auditor, can_create_group: true))

        expect { subject }.to change { Group.count }.by(1)

        expect(response).to have_gitlab_http_status(:found)
      end
    end

    it_behaves_like GroupInviteMembers do
      before do
        sign_in(user)
      end
    end

    context 'when creating a group with `default_branch_protection` attribute' do
      subject do
        post :create, params: { group: group_params.merge(default_branch_protection: Gitlab::Access::PROTECTION_NONE) }
      end

      shared_examples_for 'creates the group with the expected `default_branch_protection` value' do
        it 'creates the group with the expected `default_branch_protection` value' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(Group.last.default_branch_protection).to eq(default_branch_protection)
        end
      end

      context 'authenticated as an admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            sign_in(user)

            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'creates the group with the expected `default_branch_protection` value'
        end
      end

      context 'authenticated a normal user' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            sign_in(user)

            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'creates the group with the expected `default_branch_protection` value'
        end
      end
    end
  end

  describe 'PUT #update' do
    let_it_be(:group, refind: true) { create(:group) }

    context 'when max_pages_size param is specified' do
      let(:params) { { max_pages_size: 100 } }

      let(:request) do
        post :update, params: { id: group.to_param, group: params }
      end

      before do
        stub_licensed_features(pages_size_limit: true)
        group.add_owner(user)
        sign_in(user)
      end

      context 'when user is an admin with admin mode enabled', :enable_admin_mode do
        let(:user) { create(:admin) }

        it 'updates max_pages_size' do
          request

          expect(group.reload.max_pages_size).to eq(100)
        end
      end

      context 'when user is an admin with admin mode disabled' do
        it 'does not update max_pages_size' do
          request

          expect(group.reload.max_pages_size).to eq(nil)
        end
      end

      context 'when user is not an admin' do
        it 'does not update max_pages_size' do
          request

          expect(group.reload.max_pages_size).to eq(nil)
        end
      end
    end

    context 'when `max_personal_access_token_lifetime` is specified' do
      let_it_be(:managed_group) do
        create(:group_with_managed_accounts, :private, max_personal_access_token_lifetime: 1)
      end

      let_it_be(:user) { create(:user, :group_managed, managing_group: managed_group ) }

      let(:params) { { max_personal_access_token_lifetime: max_personal_access_token_lifetime } }
      let(:max_personal_access_token_lifetime) { 10 }

      subject do
        put :update, params: { id: managed_group.to_param, group: params }
      end

      before do
        allow_any_instance_of(EE::Group).to receive(:enforced_group_managed_accounts?).and_return(true)

        managed_group.add_owner(user)
        sign_in(user)
      end

      context 'without `personal_access_token_expiration_policy` licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: false)
        end

        it 'does not update the attribute' do
          expect { subject }.not_to change { managed_group.reload.max_personal_access_token_lifetime }
        end

        it "doesn't call the update lifetime service" do
          expect(::PersonalAccessTokens::Groups::UpdateLifetimeService).not_to receive(:new)

          subject
        end
      end

      context 'with personal_access_token_expiration_policy licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: true)
        end

        context 'when `max_personal_access_token_lifetime` is updated to a non-null value' do
          it 'updates the attribute' do
            subject

            expect(managed_group.reload.max_personal_access_token_lifetime).to eq(max_personal_access_token_lifetime)
          end

          it 'executes the update lifetime service' do
            expect_next_instance_of(::PersonalAccessTokens::Groups::UpdateLifetimeService, managed_group) do |service|
              expect(service).to receive(:execute)
            end

            subject
          end
        end

        context 'when `max_personal_access_token_lifetime` is updated to null value' do
          let(:max_personal_access_token_lifetime) { nil }

          it 'updates the attribute' do
            subject

            expect(managed_group.reload.max_personal_access_token_lifetime).to eq(max_personal_access_token_lifetime)
          end

          it "doesn't call the update lifetime service" do
            expect(::PersonalAccessTokens::Groups::UpdateLifetimeService).not_to receive(:new)

            subject
          end
        end
      end
    end

    context 'when `default_branch_protection` is specified' do
      let(:params) do
        { id: group.to_param, group: { default_branch_protection: Gitlab::Access::PROTECTION_NONE } }
      end

      subject { put :update, params: params }

      shared_examples_for 'updates the attribute' do
        it 'updates the attribute' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.default_branch_protection).to eq(default_branch_protection)
        end
      end

      context 'authenticated as admin', :enable_admin_mode do
        let_it_be(:user) { create(:admin) }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            sign_in(user)

            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'updates the attribute'
        end
      end

      context 'authenticated as group owner' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          false | false | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            group.add_owner(user)
            sign_in(user)

            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it_behaves_like 'updates the attribute'
        end
      end
    end

    context 'when `delayed_project_removal` and `lock_delayed_project_removal` params are specified' do
      let_it_be(:params) { { delayed_project_removal: true, lock_delayed_project_removal: true } }
      let_it_be(:user) { create(:user) }

      subject do
        put :update, params: { id: group.to_param, group: params }
      end

      before do
        group.add_owner(user)
        sign_in(user)
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: available)
      end

      context 'when feature is available' do
        let(:available) { true }

        it 'allows storing of settings' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.namespace_settings.delayed_project_removal).to eq(params[:delayed_project_removal])
          expect(group.reload.namespace_settings.lock_delayed_project_removal).to eq(params[:lock_delayed_project_removal])
        end
      end

      context 'when feature is not available' do
        let(:available) { false }

        it 'does not allow storing of settings' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.namespace_settings.delayed_project_removal).not_to eq(params[:delayed_project_removal])
          expect(group.reload.namespace_settings.lock_delayed_project_removal).not_to eq(params[:lock_delayed_project_removal])
        end
      end
    end

    context 'when `prevent_forking_outside_group` is specified' do
      subject { put :update, params: params }

      shared_examples_for 'updates the attribute if needed' do
        it 'updates the attribute' do
          subject

          expect(response).to have_gitlab_http_status(:found)
          expect(group.reload.prevent_forking_outside_group?).to eq(result)
        end
      end

      context 'authenticated as group owner' do
        where(:feature_enabled, :prevent_forking_outside_group, :result) do
          false | false | nil
          false | true  | nil
          true  | false | false
          true  | true  | true
        end

        with_them do
          let(:params) do
            { id: group.to_param, group: { prevent_forking_outside_group: prevent_forking_outside_group } }
          end

          before do
            group.add_owner(user)
            sign_in(user)

            stub_licensed_features(group_forking_protection: feature_enabled)
          end

          it_behaves_like 'updates the attribute if needed'
        end
      end
    end

    context 'when `new_user_signups_cap` is specified' do
      subject { put :update, params: params }

      shared_examples_for 'updates the attribute' do
        it 'updates the attribute' do
          subject

          expect(response).to have_gitlab_http_status(status)
          expect(group.reload.new_user_signups_cap).to eq(result)
        end
      end

      context 'authenticated as group owner' do
        before do
          allow_next_found_instance_of(Group) do |group|
            allow(group).to receive(:user_cap_available?).and_return(true)
          end

          group.add_owner(user)
          sign_in(user)
        end

        where(:new_user_signups_cap, :result, :status) do
          nil | nil   | :found
          10  | 10    | :found
        end

        with_them do
          let(:params) do
            { id: group.to_param, group: { new_user_signups_cap: new_user_signups_cap } }
          end

          it_behaves_like 'updates the attribute'
        end
      end
    end

    context 'when group feature setting `wiki_access_level` is specified' do
      before do
        stub_licensed_features(group_wikis: true)
        group.add_owner(user)

        sign_in(user)
      end

      it 'updates the attribute' do
        [Featurable::PRIVATE, Featurable::DISABLED, Featurable::ENABLED].each do |visibility_level|
          request(visibility_level)

          expect(group.reload.group_feature.wiki_access_level).to eq(visibility_level)
        end
      end

      context 'when group wiki licensed feature is not enabled for the group' do
        it 'does not update the attribute' do
          stub_licensed_features(group_wikis: false)

          expect { request(Featurable::PRIVATE) }.not_to change { group.reload.group_feature.wiki_access_level }
        end
      end

      def request(visibility_level)
        put :update, params: { id: group.to_param, group: { group_feature_attributes: { wiki_access_level: visibility_level } } }
      end
    end
  end
end
