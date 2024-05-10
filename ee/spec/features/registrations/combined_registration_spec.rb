# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Registration group and project creation flow', :js, feature_category: :onboarding do
  include SaasRegistrationHelpers

  let_it_be(:user) { create(:user, onboarding_in_progress: true) }

  before do
    # https://gitlab.com/gitlab-org/gitlab/-/issues/340302
    allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(160)

    # Stubbed not to break query budget. Should be safe as the query only happens on SaaS and the result is cached
    allow(Gitlab::Com).to receive(:gitlab_com_group_member?).and_return(nil)

    stub_saas_features(onboarding: true)
    stub_application_setting(import_sources: %w[github gitlab_project])
    sign_in(user)
    visit users_sign_up_welcome_path

    expect(page).to have_content('Welcome to GitLab') # rubocop:disable RSpec/ExpectInHook

    choose 'Just me'
    choose 'Create a new project'
    click_on 'Continue'
  end

  it 'A user can create a group and project' do
    within_testid('url-group-path') do
      expect(page).to have_content('{group}')
    end

    within_testid('url-project-path') do
      expect(page).to have_content('{project}')
    end

    fill_in 'group_name', with: '@_'
    fill_in 'blank_project_name', with: 'test project'

    within_testid('url-group-path') do
      expect(page).to have_content('_')
    end

    within_testid('url-project-path') do
      expect(page).to have_content('test-project')
    end

    click_on 'Create project'

    expect_filled_form_and_error_message

    fill_in 'group_name', with: 'test group'

    within_testid('url-group-path') do
      expect(page).to have_content('test-group')
    end

    click_on 'Create project'

    expect_to_be_in_learn_gitlab
  end

  it 'a user can create a group and import a project' do
    click_on 'Import'

    within_testid('url-group-path') do
      expect(page).to have_content('{group}')
    end

    click_on 'GitHub'

    page.within('.gl-field-error') do
      expect(page).to have_content('This field is required.')
    end

    fill_in 'import_group_name', with: 'test group'

    within_testid('url-group-path') do
      expect(page).to have_content('test-group')
    end

    click_on 'GitHub'

    expect(page).to have_content('To import GitHub repositories, you must first authorize GitLab to')
  end

  context 'with readme status honored on failures' do
    it 'honors previous include readme checkbox setting' do
      fill_in 'group_name', with: '@@@' # this forces the error
      fill_in 'blank_project_name', with: 'Test Project'
      uncheck 'Include a Getting Started README'
      click_on 'Create project'

      expect(find_field('Include a Getting Started README')).not_to be_checked
    end
  end

  def expect_filled_form_and_error_message
    expect(find_by_testid('group-name').value).to eq('@_')
    expect(find_by_testid('project-name').value).to eq('test project')

    page.within('#error_explanation') do
      expect(page).to have_content('The Group contains the following errors')
    end
  end
end
