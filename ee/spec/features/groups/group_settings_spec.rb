# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Edit group settings', :js, feature_category: :groups_and_projects do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:group, refind: true) { create(:group, name: 'Foo bar', path: 'foo', owners: user, developers: developer) }

  before do
    sign_in(user)
  end

  describe 'navbar' do
    context 'with LDAP enabled' do
      before do
        allow_next_found_instance_of(Group) do |instance|
          allow(instance).to receive(:ldap_synced?).and_return(true)
        end
        allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(true)
      end

      it 'is able to navigate to LDAP group section' do
        visit edit_group_path(group)

        within_testid('super-sidebar') do
          expect(page).to have_content('LDAP Synchronization')
        end
      end

      context 'with owners not being able to manage LDAP' do
        it 'is not able to navigate to LDAP group section' do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)

          visit edit_group_path(group)

          within_testid('super-sidebar') do
            expect(page).not_to have_content('LDAP Synchronization')
          end
        end
      end
    end
  end

  context 'with webhook feature enabled' do
    it 'shows the menu item' do
      stub_licensed_features(group_webhooks: true)

      visit edit_group_path(group)

      within_testid('super-sidebar') do
        expect(page).to have_link('Webhooks')
      end
    end
  end

  context 'with webhook feature disabled' do
    it 'does not show the menu item' do
      stub_licensed_features(group_webhooks: false)

      visit edit_group_path(group)

      within_testid('super-sidebar') do
        expect(page).not_to have_link('Webhooks')
      end
    end
  end

  describe 'Member Lock setting' do
    let(:membership_lock_text) { 'Users cannot be added to projects in this group' }

    context 'without a license key' do
      before do
        License.destroy_all # rubocop: disable Cop/DestroyAll
      end

      it 'is not visible' do
        visit edit_group_path(group)

        expect(page).not_to have_content(membership_lock_text)
      end

      context 'available through usage ping features' do
        before do
          stub_usage_ping_features(true)
        end

        it 'is visible' do
          visit edit_group_path(group)

          expect(page).to have_content(membership_lock_text)
        end

        context 'when current user is not the Owner' do
          before do
            sign_in(developer)
          end

          it 'is not visible' do
            visit edit_group_path(group)

            expect(page).not_to have_content(membership_lock_text)
          end
        end
      end
    end

    context 'with a license key' do
      it 'is visible' do
        visit edit_group_path(group)

        expect(page).to have_content(membership_lock_text)
      end

      context 'when current user is not the Owner' do
        before do
          sign_in(developer)
        end

        it 'is not visible' do
          visit edit_group_path(group)

          expect(page).not_to have_content(membership_lock_text)
        end
      end
    end
  end

  describe 'Group file templates setting', :js do
    context 'without a license key' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'is not visible' do
        visit edit_group_path(group)

        expect(page).not_to have_content('Select a template repository')
      end

      context 'available through usage ping features' do
        before do
          stub_usage_ping_features(true)
        end

        it 'is visible' do
          visit edit_group_path(group)

          expect(page).to have_content('Select a template repository')
        end

        context 'when current user is not the Owner' do
          before do
            sign_in(developer)
          end

          it 'is not visible' do
            visit edit_group_path(group)

            expect(page).not_to have_content('Select a template repository')
          end
        end
      end
    end

    context 'with a license key' do
      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
      end

      it 'is visible' do
        visit edit_group_path(group)

        expect(page).to have_content('Select a template repository')
      end

      it 'allows a project to be selected', :js do
        project = create(:project, namespace: group, name: 'known project')

        visit edit_group_path(group)

        page.within('section#js-templates') do |page|
          select_from_listbox(project.name_with_namespace, from: 'Search for project')
          click_button 'Save changes'
          wait_for_requests

          expect(group.reload.checked_file_template_project).to eq(project)
        end
      end

      context 'when current user is not the Owner' do
        before do
          sign_in(developer)
        end

        it 'is not visible' do
          visit edit_group_path(group)

          expect(page).not_to have_content('Select a template repository')
        end
      end
    end
  end

  context 'delayed project deletion' do
    let(:form_group_selector) { '[data-testid="delayed-project-removal-form-group"]' }

    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
    end

    describe 'immediately deleting a project marked for deletion', :js do
      before do
        create(:group_deletion_schedule, group: group, marked_for_deletion_on: 2.days.from_now)

        visit edit_group_path(group)
      end

      it 'deletes the project immediately', :sidekiq_inline do
        expect { remove_with_confirm('Delete group', group.path) }.to change { Group.count }.by(-1)

        expect(page).to have_content "is being deleted"
      end

      def remove_with_confirm(button_text, confirm_with, confirm_button_text = 'Confirm')
        click_button button_text
        fill_in 'confirm_name_input', with: confirm_with
        click_button confirm_button_text
      end
    end

    it 'does not display delayed project removal field at group level', :js do
      visit edit_group_path(group)

      expect(page).not_to have_css(form_group_selector)
    end
  end

  context 'when custom_project_templates feature' do
    let!(:subgroup) { create(:group, :public, parent: group) }
    let!(:subgroup_1) { create(:group, :public, parent: subgroup) }

    shared_examples 'shows custom project templates settings' do
      it 'shows the custom project templates selection menu' do
        expect(page).to have_content('Custom project templates')
      end

      context 'group selection menu', :js do
        it 'shows only the subgroups' do
          click_button 'Search for a group'

          expect_listbox_items(["#{nested_group.full_name}\n#{nested_group.full_path}"])
        end
      end
    end

    shared_examples 'does not show custom project templates settings' do
      it 'does not show the custom project templates selection menu' do
        expect(page).not_to have_content('Custom project templates')
      end
    end

    context 'is enabled' do
      before do
        stub_licensed_features(group_project_templates: true)
        visit edit_group_path(selected_group)
      end

      context 'when the group is a top parent group' do
        let(:selected_group) { group }
        let(:nested_group) { subgroup }

        it_behaves_like 'shows custom project templates settings'
      end

      context 'when the group is a subgroup' do
        let(:selected_group) { subgroup }
        let(:nested_group) { subgroup_1 }

        it_behaves_like 'shows custom project templates settings'
      end
    end

    context 'namespace plan is checked', :saas do
      before do
        create(:gitlab_subscription, namespace: group, hosted_plan: plan)
        stub_licensed_features(group_project_templates: true)
        allow(Gitlab::CurrentSettings.current_application_settings)
          .to receive(:should_check_namespace_plan?).and_return(true)

        visit edit_group_path(selected_group)
      end

      context 'namespace is on the proper plan' do
        let(:plan) { create(:ultimate_plan) }

        context 'when the group is a top parent group' do
          let(:selected_group) { group }
          let(:nested_group) { subgroup }

          it_behaves_like 'shows custom project templates settings'
        end

        context 'when the group is a subgroup' do
          let(:selected_group) { subgroup }
          let(:nested_group) { subgroup_1 }

          it_behaves_like 'shows custom project templates settings'
        end
      end

      context 'is disabled for namespace' do
        let(:plan) { create(:bronze_plan) }

        context 'when the group is the top parent group' do
          let(:selected_group) { group }

          it_behaves_like 'does not show custom project templates settings'
        end

        context 'when the group is a subgroup' do
          let(:selected_group) { subgroup }

          it_behaves_like 'does not show custom project templates settings'
        end
      end
    end

    context 'is disabled' do
      before do
        stub_licensed_features(group_project_templates: false)
        visit edit_group_path(selected_group)
      end

      context 'when the group is the top parent group' do
        let(:selected_group) { group }

        it_behaves_like 'does not show custom project templates settings'
      end

      context 'when the group is a subgroup' do
        let(:selected_group) { subgroup }

        it_behaves_like 'does not show custom project templates settings'
      end
    end
  end

  describe 'merge request approval settings', :js do
    let_it_be(:approval_settings) do
      create(:group_merge_request_approval_setting, group: group, allow_author_approval: false)
    end

    context 'when group is licensed' do
      before do
        stub_licensed_features(merge_request_approvers: true)
      end

      it 'allows to save settings' do
        visit edit_group_path(group)
        wait_for_all_requests

        expect(page).to have_content('Merge request approvals')

        within_testid('merge-request-approval-settings') do
          click_button 'Expand'
          checkbox = find('[data-testid="prevent-author-approval"] > input')

          expect(checkbox).to be_checked

          checkbox.set(false)
          click_button 'Save changes'
          wait_for_all_requests
        end

        visit edit_group_path(group)
        wait_for_all_requests

        within_testid('merge-request-approval-settings') do
          click_button 'Expand'
          expect(find('[data-testid="prevent-author-approval"] > input')).not_to be_checked
        end
      end
    end

    context 'when group is not licensed' do
      before do
        stub_licensed_features(merge_request_approvers: false)
      end

      it 'is not visible' do
        visit edit_group_path(group)

        expect(page).not_to have_content('Merge request approvals')
      end
    end
  end

  describe 'permissions and group features', :js do
    context 'for service access token enforced setting' do
      context 'when saas', :saas do
        context 'when service accounts feature enabled' do
          before do
            stub_licensed_features(service_accounts: true)
          end

          it 'renders service access token enforced checkbox' do
            visit edit_group_path(group)
            wait_for_all_requests

            expect(page).to have_content('Service account token expiration')

            within(permissions_selector) do
              checkbox = find(service_access_token_expiration_enforced_selector)

              expect(checkbox).to be_checked

              checkbox.set(false)
              click_button 'Save changes'
              wait_for_all_requests
            end

            visit edit_group_path(group)
            wait_for_all_requests

            within(permissions_selector) do
              expect(find(service_access_token_expiration_enforced_selector)).not_to be_checked
            end
          end

          context 'when group is not the root group' do
            let(:subgroup) { create(:group, parent: group) }

            it "does not render service account token enforced checkbox" do
              visit edit_group_path(subgroup)
              wait_for_all_requests

              expect(page).not_to have_content('Service account token expiration')
            end
          end
        end

        context 'when service accounts feature not enabled' do
          it 'renders service access token enforced checkbox' do
            visit edit_group_path(group)
            wait_for_all_requests

            expect(page).not_to have_content('Service account token expiration')
          end
        end
      end

      context 'when not saas' do
        it "does not render service access token enforced checkbox" do
          visit edit_group_path(group)
          wait_for_all_requests

          expect(page).not_to have_content('Service account token expiration')
        end
      end

      def service_access_token_expiration_enforced_selector
        '[data-testid="service_access_tokens_expiration_enforced_checkbox"]'
      end
    end

    def permissions_selector
      '[data-testid="permissions-settings"]'
    end
  end

  describe 'email domain validation', :js do
    let(:domain_field_selector) { '[placeholder="example.com"]' }

    before do
      stub_licensed_features(group_allowed_email_domains: true)
    end

    def update_email_domains(new_domain)
      visit edit_group_path(group)

      find(domain_field_selector).set(new_domain)
      find(domain_field_selector).send_keys(:enter)
    end

    it 'is visible' do
      visit edit_group_path(group)

      expect(page).to have_content("Restrict membership by email domain")
    end

    it 'displays an error for invalid emails' do
      new_invalid_domain = "gitlab./com!"

      update_email_domains(new_invalid_domain)

      expect(page).to have_content("The domain you entered is misformatted")
    end

    it 'will save valid domains' do
      new_domain = "gitlab.com"

      update_email_domains(new_domain)

      expect(page).not_to have_content("The domain you entered is misformatted")

      click_button 'Save changes'
      wait_for_requests

      expect(page).to have_content("Group 'Foo bar' was successfully updated.")
    end
  end

  describe 'user caps settings' do
    let(:user_cap_available) { true }

    before do
      allow_next_found_instance_of(Group) do |instance|
        allow(instance).to receive(:user_cap_available?).and_return user_cap_available
      end
    end

    context 'when user cap feature is unavailable' do
      let(:user_cap_available) { false }

      before do
        visit edit_group_path(group)
      end

      it 'is not visible' do
        expect(page).not_to have_content('User cap')
      end
    end

    context 'when user cap feature is available', :js do
      let(:user_caps_selector) { '[name="group[new_user_signups_cap]"]' }

      context 'when group is not the root group' do
        let(:subgroup) { create(:group, parent: group) }

        before do
          visit edit_group_path(subgroup)
        end

        it 'is not visible' do
          expect(page).not_to have_content('User cap')
        end
      end

      context 'when the group is the root group' do
        before do
          visit edit_group_path(group)
        end

        it 'is visible' do
          expect(page).to have_content('User cap')
        end

        it 'will save positive numbers' do
          find(user_caps_selector).set(5)

          click_button 'Save changes'
          wait_for_requests

          expect(page).to have_content("Group 'Foo bar' was successfully updated.")
        end

        it 'will not allow negative number' do
          find(user_caps_selector).set(-5)

          click_button 'Save changes'
          expect(page).to have_content('This field is required.')

          wait_for_requests

          expect(page).not_to have_content("Group 'Foo bar' was successfully updated.")
        end

        context 'when the group cannot set a user cap' do
          before do
            create(:group_group_link, shared_group: group)

            visit edit_group_path(group)
          end

          it 'will be a disabled input' do
            expect(find(user_caps_selector)).to be_disabled
          end
        end
      end
    end

    describe 'form submit button', :js do
      def fill_in_new_user_signups_cap(new_user_signups_cap_value)
        page.within('#js-permissions-settings') do
          fill_in 'group[new_user_signups_cap]', with: new_user_signups_cap_value
          click_button 'Save changes'
        end
      end

      shared_examples 'successful form submit' do
        it 'shows form submit successful message' do
          fill_in_new_user_signups_cap(new_user_signups_cap_value)

          expect(page).to have_content("Group 'Foo bar' was successfully updated.")
        end
      end

      shared_examples 'confirmation modal before submit' do
        it 'shows #confirm-general-permissions-changes modal' do
          fill_in_new_user_signups_cap(new_user_signups_cap_value)

          expect(page).to have_selector('#confirm-general-permissions-changes')
          expect(page).to have_css('#confirm-general-permissions-changes .modal-body', text: 'By making this change, you will automatically approve all users who are pending approval.')
        end
      end

      before do
        group.namespace_settings.update!(new_user_signups_cap: group.group_members.count)
      end

      context 'if user cap changes from limited to unlimited' do
        before do
          visit edit_group_path(group, anchor: 'js-permissions-settings')
        end

        it_behaves_like 'confirmation modal before submit' do
          let(:new_user_signups_cap_value) { nil }
        end
      end

      context 'when the auto approve pending users feature flag is enabled' do
        before do
          stub_feature_flags(saas_user_caps_auto_approve_pending_users_on_cap_increase: true)
          visit edit_group_path(group, anchor: 'js-permissions-settings')
        end

        it 'shows correct helper text' do
          expect(page).to have_content 'After the instance reaches the user cap, any user who is added or requests access must be approved by an administrator'
          expect(page).not_to have_content 'Increasing the user cap does not automatically approve pending users'
        end

        context 'should show confirmation modal' do
          context 'if user cap increases' do
            it_behaves_like 'confirmation modal before submit' do
              let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap + 1 }
            end
          end
        end

        context 'should not show confirmation modal' do
          context 'if user cap decreases' do
            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap - 1 }
            end
          end

          context 'if user cap changes from unlimited to limited' do
            before do
              group.namespace_settings.update!(new_user_signups_cap: nil)
              visit edit_group_path(group, anchor: 'js-permissions-settings')
            end

            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { 1 }
            end
          end
        end
      end

      context 'when the auto approve pending users feature flag is disabled' do
        before do
          stub_feature_flags(saas_user_caps_auto_approve_pending_users_on_cap_increase: false)
          visit edit_group_path(group, anchor: 'js-permissions-settings')
        end

        it 'shows correct helper text' do
          expect(page).to have_content 'Increasing the user cap does not automatically approve pending users'
        end

        context 'should not show confirmation modal' do
          context 'if user cap increases' do
            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap + 1 }
            end
          end

          context 'if user cap decreases' do
            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap - 1 }
            end
          end

          context 'if user cap changes from unlimited to limited' do
            before do
              group.namespace_settings.update!(new_user_signups_cap: nil)
              visit edit_group_path(group, anchor: 'js-permissions-settings')
            end

            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { 1 }
            end
          end
        end
      end
    end
  end

  describe 'prevent sharing outside group hierarchy setting' do
    context 'when block seat overages is enabled', :saas do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        stub_feature_flags(block_seat_overages: true)
      end

      it 'is not present' do
        visit edit_group_path(group)

        expect(page).to have_text "Permissions"
        expect(page).not_to have_selector('#group_prevent_sharing_groups_outside_hierarchy')
      end
    end
  end

  def save_permissions_group
    page.within('.gs-permissions') do
      click_button 'Save changes'
    end
  end
end
