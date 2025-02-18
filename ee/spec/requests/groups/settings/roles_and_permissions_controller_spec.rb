# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::RolesAndPermissionsController, feature_category: :user_management do
  include AdminModeHelper

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  describe 'GET #index' do
    subject(:get_index) { get(group_settings_roles_and_permissions_path(group)) }

    shared_examples 'page is not found' do
      it 'has correct status' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    shared_examples 'page is found under proper conditions' do
      it 'returns a 200 status code' do
        get_index

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when accessing a subgroup' do
        let_it_be(:subgroup) { create(:group, parent: group) }

        it 'is not found' do
          get group_settings_roles_and_permissions_path(subgroup)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when `custom_roles` license is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it_behaves_like 'page is not found'
      end
    end

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when not logged in' do
      it_behaves_like 'page is not found'
    end

    context 'with different access levels not allowed' do
      where(access_level: [nil, :guest, :reporter, :developer, :maintainer])

      with_them do
        before do
          group.add_member(user, access_level)
          sign_in(user)
        end

        it_behaves_like 'page is not found'
      end
    end

    context 'with admins' do
      let_it_be(:admin) { create(:admin) }

      before do
        sign_in(admin)
        enable_admin_mode!(admin)
      end

      it_behaves_like 'page is found under proper conditions'

      context 'on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it_behaves_like 'page is not found'
      end
    end

    context 'with group owners' do
      before do
        group.add_member(user, :owner)
        sign_in(user)
      end

      it_behaves_like 'page is found under proper conditions'
    end

    context 'with ldap synced group owner' do
      let_it_be(:group_link) { create(:ldap_group_link, group: group, group_access: Gitlab::Access::OWNER) }
      let_it_be(:group_member) { create(:group_member, :owner, :ldap, :active, user: user, source: group) }

      before do
        stub_application_setting(lock_memberships_to_ldap: true)
        sign_in(user)
      end

      it_behaves_like 'page is found under proper conditions'
    end
  end
end
