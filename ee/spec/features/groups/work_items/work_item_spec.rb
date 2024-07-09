# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be_with_reload(:user) { create(:user) }

  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:work_item) { create(:work_item, :epic, :group_level, namespace: group) }
  let(:work_items_path) { group_work_item_path(group, work_item.iid) }

  context 'for signed in user' do
    before do
      group.add_developer(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- we can remove this when we have more ee features specs
      sign_in(user)
      visit work_items_path
    end

    it_behaves_like 'work items rolled up dates'

    context 'for epics' do
      it 'shows the correct breadcrumbs' do
        within_testid('breadcrumb-links') do
          expect(page).to have_link(group.name, href: group_path(group))
          expect(page).to have_link('Epics', href: group_epics_path(group))
          expect(find('li:last-of-type')).to have_link(work_item.to_reference, href: work_items_path)
        end
      end
    end

    context 'for other work items' do
      let_it_be(:work_item) { create(:work_item, :issue, :group_level, namespace: group) }

      it 'shows the correct breadcrumbs' do
        within_testid('breadcrumb-links') do
          expect(page).to have_link(group.name, href: group_path(group))
          expect(page).to have_link('Issues', href: issues_group_path(group))
          expect(find('li:last-of-type')).to have_link(work_item.to_reference, href: work_items_path)
        end
      end
    end
  end
end
