# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project > Settings > Packages and registries > Dependency proxy for Packages',
  feature_category: :package_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, namespace: user.namespace) }

  subject(:visit_page) { visit project_settings_packages_and_registries_path(project) }

  before do
    stub_licensed_features(dependency_proxy_for_packages: true)
    stub_config(dependency_proxy: { enabled: true })

    sign_in(user)
  end

  context 'as owner', :js do
    it 'passes axe automated accessibility testing' do
      visit_page

      wait_for_requests

      # rubocop:disable Capybara/TestidFinders -- Helper within_testid doesn't cover use case
      expect(page).to be_axe_clean.within('[data-testid="packages-and-registries-project-settings"]')
                                  .skipping :'heading-order'
      # rubocop:enable Capybara/TestidFinders
    end

    it 'shows available section' do
      visit_page

      within_testid('dependency-proxy-settings') do
        expect(page).to have_text 'Dependency Proxy'
      end
    end

    it 'allows toggling dependency proxy & adding maven URL' do
      visit_page

      within_testid('dependency-proxy-settings') do
        click_button class: 'gl-toggle'
        fill_in('URL', with: 'http://example.com')
        click_button 'Save changes'
      end

      expect(page).to have_content('Settings saved successfully.')
    end

    it 'allows filling complete form' do
      visit_page

      within_testid('dependency-proxy-settings') do
        click_button class: 'gl-toggle'
        fill_in('URL', with: 'http://example.com')
        fill_in('Username', with: 'username')
        fill_in('Password', with: 'password')
        click_button 'Save changes'
      end

      expect(page).to have_content('Settings saved successfully.')
    end

    it 'shows an error when username is supplied without password' do
      visit_page

      within_testid('dependency-proxy-settings') do
        fill_in('Username', with: 'user1')
        click_button 'Save changes'
      end

      expect(page).to have_content("Maven external registry password can't be blank")
    end

    context 'with existing settings' do
      let_it_be_with_reload(:dependency_proxy_setting) do
        create(:dependency_proxy_packages_setting, :maven, project: project)
      end

      it 'allows clearing username' do
        visit_page

        within_testid('dependency-proxy-settings') do
          fill_in('Username', with: '')
          click_button 'Save changes'
        end

        expect(page).to have_content('Settings saved successfully.')
      end
    end
  end
end
