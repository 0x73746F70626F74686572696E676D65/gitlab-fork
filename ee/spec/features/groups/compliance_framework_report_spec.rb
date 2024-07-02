# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Compliance framework', :js, feature_category: :compliance_management do
  include GraphqlHelpers
  include ListboxHelpers
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:admin_user) { create(:user, :with_namespace, admin: true) }
  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:project_1) { create(:project, :repository, group: group) }
  let_it_be(:project_2) { create(:project, :repository, group: group) }
  let_it_be(:project_3) { create(:project, :repository, group: sub_group) }
  let_it_be(:compliance_framework_a) { create(:compliance_framework, namespace: group, name: 'FrameworkA') }
  let_it_be(:compliance_framework_b) { create(:compliance_framework, namespace: group, name: 'FrameworkB') }
  let_it_be(:framework_settings_first) do
    create(:compliance_framework_project_setting, project: project_1,
      compliance_management_framework: compliance_framework_a)
  end

  let_it_be(:framework_settings_second) do
    create(:compliance_framework_project_setting, project: project_3,
      compliance_management_framework: compliance_framework_b)
  end

  let(:default_framework_element) { find_by_testid('compliance-framework-default-label') }
  let(:framework_element) { find_by_testid('compliance-framework-label') }
  let(:associated_project_selector) { 'td[data-label="Associated projects"]' }

  before_all do
    group.add_owner(admin_user)
  end

  before do
    sign_in(admin_user)
  end

  context 'with top level group and subgroup' do
    context 'with compliance dashboard feature enabled' do
      before do
        group.namespace_settings.update!(default_compliance_framework_id: compliance_framework_a.id)
        stub_licensed_features(group_level_compliance_dashboard: true, custom_compliance_frameworks: true,
          compliance_framework: true)
      end

      it 'shows frameworks with associated projects in compliance center', :aggregate_failures do
        visit group_security_compliance_dashboard_path(group, vueroute: :frameworks)
        wait_for_requests
        expect(default_framework_element).to have_content(compliance_framework_a.name)

        expect(default_framework_element.find(:xpath, "../../../../..")
                                        .find(associated_project_selector).text).to eq(project_1.name)

        expect(framework_element).to have_content(compliance_framework_b.name)

        expect(framework_element.find(:xpath, "../../../../..")
                                .find(associated_project_selector).text).to eq(project_3.name)

        expect(page).not_to have_content(project_2.name)
      end

      context 'with new projects', :sidekiq_inline do
        before do
          group.namespace_settings.reload.update!(default_compliance_framework_id: compliance_framework_a.id)
        end

        let(:new_project) { 'Project 4' }

        it 'applies default compliance framework' do
          create_project(new_project, sub_group)
          visit group_security_compliance_dashboard_path(group, vueroute: :frameworks)
          wait_for_requests
          expect(default_framework_element.find(:xpath, "../../../../..")
                                          .find(associated_project_selector).text).to include(new_project)
        end
      end

      context 'with delete compliance framework' do
        let_it_be(:compliance_framework_to_delete) do
          create(:compliance_framework,
            namespace: group, name: 'compliance_framework_to_delete')
        end

        let_it_be(:framework_setting) do
          create(:compliance_framework_project_setting, project: project_1,
            compliance_management_framework: compliance_framework_to_delete)
        end

        it 'removes compliance framework from associated project', :aggregate_failures do
          delete_compliance_framework(compliance_framework_to_delete.name, group)
          expect(page).not_to have_content(compliance_framework_to_delete.name)
          visit group_security_compliance_dashboard_path(group, vueroute: :projects)
          wait_for_requests
          expect(page).not_to have_content(compliance_framework_to_delete.name)
          visit(project_path(project_1))
          wait_for_requests
          expect(page).not_to have_content(compliance_framework_to_delete.name)
        end
      end
    end

    context 'with compliance dashboard feature disabled' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: false)
      end

      it 'renders 404 for compliance center path' do
        visit group_security_compliance_framework_reports_path(group)
        expect(page).to have_content('Not Found')
      end
    end
  end

  private

  def create_project(project_name, group)
    visit(new_project_path)
    wait_for_requests
    click_link 'Create blank project'
    fill_in(:project_name, with: project_name)

    click_on 'Pick a group or namespace'
    select_listbox_item group.full_path

    page.within('#content-body') { click_button('Create project') }
  end

  def delete_compliance_framework(framework_name, group)
    visit group_security_compliance_dashboard_path(group, vueroute: :frameworks)
    find('td', text: framework_name).click
    click_button('Edit framework')
    wait_for_requests
    click_button('Delete framework')
    within_modal do
      click_button('Delete framework')
    end
  end
end
