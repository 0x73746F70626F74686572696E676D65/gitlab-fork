# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Google Artifact Registry', :js, feature_category: :container_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  before_all do
    project.add_developer(user)
  end

  before do
    stub_container_registry_config(enabled: true)
    stub_saas_features(google_artifact_registry: true)
    sign_in(user)
  end

  it 'passes axe automated accessibility testing' do
    visit_page

    wait_for_requests

    # rubocop:disable Capybara/TestidFinders -- Helper within_testid doesn't cover use case
    expect(page).to be_axe_clean.within('[data-testid="artifact-registry-list-page"]')
    # rubocop:enable Capybara/TestidFinders
  end

  it 'has a page title set' do
    visit_page

    expect(page).to have_title _('Google Artifact Registry')
  end

  it 'has external link to google cloud' do
    visit_page

    expect(page).to have_link _('Open in Google Cloud')
  end

  private

  def visit_page
    visit project_google_cloud_platform_artifact_registry_index_path(project)
  end
end
