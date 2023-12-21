# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Members > Leave group', feature_category: :groups_and_projects do
  include Features::MembersHelpers
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:other_user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:user) { create(:user) }
  let(:more_actions_dropdown) do
    find('[data-testid="groups-projects-more-actions-dropdown"] .gl-new-dropdown-custom-toggle')
  end

  before do
    user.update!(provisioned_by_group: group)
    sign_in(user)
  end

  context 'with block_password_auth_for_saml_users feature flag switched on' do
    it 'guest provisioned by this group leaves the group and is signed off', :js do
      group.add_guest(user)
      group.add_owner(other_user)

      visit group_path(group)
      more_actions_dropdown.click
      click_link 'Leave group'
      accept_gl_confirm(button_text: 'Leave group')

      expect(page).to have_current_path(new_user_session_path, ignore_query: true)
      expect(group).not_to have_user(user)
    end

    it 'guest leaves the group by url param and is signed off', :js do
      group.add_guest(user)
      group.add_owner(other_user)

      visit group_path(group, leave: 1)
      accept_gl_confirm(button_text: 'Leave group')
      wait_for_all_requests

      expect(page).to have_current_path(new_user_session_path, ignore_query: true)
      expect(group).not_to have_user(user)
    end
  end

  context 'with block_password_auth_for_saml_users feature flag switched off' do
    before do
      stub_feature_flags(block_password_auth_for_saml_users: false)
    end

    it 'guest leaves the group by url param', :js do
      group.add_guest(user)
      group.add_owner(other_user)

      visit group_path(group, leave: 1)
      accept_gl_confirm(button_text: 'Leave group')
      wait_for_all_requests

      expect(page).to have_current_path(dashboard_groups_path, ignore_query: true)
      expect(group).not_to have_user(user)
    end

    it 'guest leaves the group as last member', :js do
      group.add_guest(user)

      visit group_path(group)
      more_actions_dropdown.click
      click_link 'Leave group'
      accept_gl_confirm(button_text: 'Leave group')

      expect(page).to have_current_path(dashboard_groups_path, ignore_query: true)
      expect(group).not_to have_user(user)
    end
  end
end
