# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group projects page', feature_category: :groups_and_projects do
  let(:user) { create :user }
  let(:group) { create :group }

  before do
    group.add_owner(user)

    sign_in(user)
  end

  context 'when group has project pending deletion' do
    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
    end

    let!(:project) { create(:project, :archived, namespace: group, marked_for_deletion_at: Date.current) }

    it 'renders projects list' do
      visit projects_group_path(group)

      expect(page).to have_link project.name
      expect(page).not_to have_css('span.badge.badge-warning', text: 'archived')
      expect(page).to have_css('span.badge.badge-warning', text: 'Pending deletion')
    end
  end
end
