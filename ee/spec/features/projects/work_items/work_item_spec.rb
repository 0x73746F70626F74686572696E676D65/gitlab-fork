# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be_with_reload(:user) { create(:user) }

  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:project) { create(:project, :public, namespace: group) }
  let_it_be(:work_item) { create(:work_item, project: project) }
  let(:work_items_path) { project_work_item_path(project, work_item.iid) }

  context 'for signed in user' do
    before do
      project.add_developer(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- we can remove this when we have more ee features specs
      sign_in(user)
      visit work_items_path
    end

    it_behaves_like 'work items iteration'
  end
end
