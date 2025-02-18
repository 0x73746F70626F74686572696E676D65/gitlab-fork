# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project', :js, feature_category: :groups_and_projects do
  describe 'immediately deleting a project marked for deletion' do
    let(:project) { create(:project, marked_for_deletion_at: Date.current) }
    let(:user) { project.first_owner }

    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)

      sign_in user
      visit edit_project_path(project)
    end

    it 'deletes the project immediately', :sidekiq_inline do
      expect { remove_with_confirm('Delete project', project.path_with_namespace, 'Yes, delete project') }.to change { Project.count }.by(-1)

      expect(page).to have_content "Project '#{project.full_name}' is being deleted."
      expect(Project.all.count).to be_zero
    end

    def remove_with_confirm(button_text, confirm_with, confirm_button_text = 'Confirm')
      click_button button_text
      fill_in 'confirm_name_input', with: confirm_with
      click_button confirm_button_text
    end
  end

  describe 'delete project container text' do
    let_it_be(:group_settings) { create(:namespace_settings) }
    let_it_be(:group) { create(:group, :public, namespace_settings: group_settings) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }

    context 'when `feature_available_on_instance` is enabled' do
      before do
        stub_application_setting(deletion_adjourned_period: 7)
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
        group.add_member(user, Gitlab::Access::OWNER)

        sign_in user
        visit edit_project_path(project)
      end

      it 'renders the marked for removal message' do
        freeze_time do
          deletion_date = (Time.now.utc + ::Gitlab::CurrentSettings.deletion_adjourned_period.days).strftime('%F')

          expect(page).to have_content("This action deletes #{project.path_with_namespace} on #{deletion_date} and everything this project contains.")

          click_button "Delete project"

          expect(page).to have_content("This project can be restored until #{deletion_date}.")
        end
      end
    end

    context 'when `feature_available_on_instance` is disabled' do
      before do
        stub_application_setting(deletion_adjourned_period: 7)
        group.add_member(user, Gitlab::Access::OWNER)

        sign_in user
        visit edit_project_path(project)
      end

      it 'renders the permanently delete message' do
        expect(page).to have_content("This action deletes #{project.path_with_namespace} and everything this project contains. There is no going back.")

        click_button "Delete project"

        expect(page).not_to have_content(/This project can be restored/)
      end
    end
  end

  describe 'storage pre_enforcement alert', :js do
    include NamespaceStorageHelpers

    let_it_be_with_refind(:group) { create(:group, :with_root_storage_statistics) }
    let_it_be_with_refind(:user) { create(:user) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:storage_banner_text) { "A namespace storage limit of 5 GiB will soon be enforced" }

    before do
      stub_ee_application_setting(automatic_purchased_storage_allocation: true)
      stub_saas_features(namespaces_storage_limit: true)
      set_notification_limit(group, megabytes: 1000)
      set_dashboard_limit(group, megabytes: 5_120)

      group.root_storage_statistics.update!(
        storage_size: 5.gigabytes
      )
      group.add_maintainer(user)
      sign_in(user)
    end

    context 'when storage is over the notification limit' do
      it 'displays the alert in the project page' do
        visit project_path(project)

        expect(page).to have_text storage_banner_text
      end

      context 'when in a subgroup project page' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:project) { create(:project, namespace: subgroup) }

        it 'displays the alert' do
          visit project_path(project)

          expect(page).to have_text storage_banner_text
        end
      end

      context 'when in a user namespace project page' do
        let_it_be_with_refind(:project) { create(:project, namespace: user.namespace) }

        before do
          create(
            :namespace_root_storage_statistics,
            namespace: user.namespace,
            storage_size: 5.gigabytes
          )
        end

        it 'displays the alert' do
          visit project_path(project)

          expect(page).to have_text storage_banner_text
        end
      end

      it 'does not display the alert in a paid group project page' do
        allow_next_found_instance_of(Group) do |group|
          allow(group).to receive(:paid?).and_return(true)
        end

        visit project_path(project)

        expect(page).not_to have_text storage_banner_text
      end
    end

    context 'when storage is under the notification limit ' do
      before do
        set_notification_limit(group, megabytes: 10_000)
      end

      it 'does not display the alert in the group page' do
        visit project_path(project)

        expect(page).not_to have_text storage_banner_text
      end
    end
  end
end
