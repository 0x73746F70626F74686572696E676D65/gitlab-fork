# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE > Projects > Settings > Merge requests > User manages approval rules',
  feature_category: :code_review_workflow do
  let(:project) { create(:project) }
  let(:user) { project.owner }
  let(:path) { edit_project_path(project) }
  let(:licensed_features) { {} }
  let(:project_features) { {} }

  before do
    sign_in(user)
    stub_licensed_features(licensed_features)

    project.project_feature.update!(project_features)

    visit project_settings_merge_requests_path(project)
  end

  context 'when merge requests is not available' do
    let(:project_features) { { merge_requests_access_level: ::ProjectFeature::DISABLED } }

    it 'does not show approval settings' do
      expect(page).not_to have_selector('#js-merge-request-approval-settings')
    end
  end

  context 'when merge requests is available' do
    let(:project_features) { { merge_requests_access_level: ::ProjectFeature::ENABLED } }

    it 'shows approval settings' do
      expect(page).to have_selector('#js-merge-request-approval-settings')
    end

    it 'passes axe automated accessibility testing', :js do
      expect(page).to be_axe_clean.within('#js-merge-request-approval-settings').skipping :'link-in-text-block'
    end
  end

  context 'when `code_owner_approval_required` is not available' do
    let(:licensed_features) { { code_owner_approval_required: false } }

    it 'does not allow the user to require code owner approval' do
      expect(page).not_to have_content('Require approval from code owners')
    end
  end
end
