# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic show', :js, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user, name: 'Rick Sanchez', username: 'rick.sanchez') }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:public_project) { create(:project, :public, group: group) }
  let_it_be(:label1) { create(:group_label, group: group, title: 'bug') }
  let_it_be(:label2) { create(:group_label, group: group, title: 'enhancement') }
  let_it_be(:label3) { create(:group_label, group: group, title: 'documentation') }
  let_it_be(:public_issue) { create(:issue, project: public_project) }
  let_it_be(:epic_title) { 'Sample epic' }

  let_it_be(:markdown) do
    <<-MARKDOWN.strip_heredoc
    **Lorem** _ipsum_ dolor sit [amet](https://example.com), consectetur adipiscing elit.
    Nos commodius agimus.
    Ex rebus enim timiditas, non ex vocabulis nascitur.
    Ita prorsus, inquam; Duo Reges: constructio interrete.
    MARKDOWN
  end

  let_it_be(:ancestor_epic) { create(:epic, group: group, title: 'Ancestor epic') }
  let_it_be(:parent_epic) { create(:epic, group: group, title: 'Parent epic', parent: ancestor_epic) }
  let_it_be(:epic) { create(:epic, group: group, title: epic_title, description: markdown, author: user, parent: parent_epic) }
  let_it_be(:not_child) { create(:epic, group: group, title: 'not child epic', description: markdown, author: user, start_date: 50.days.ago, end_date: 10.days.ago) }
  let_it_be(:child_epic_a) { create(:epic, group: group, title: 'Child epic A', description: markdown, parent: epic, start_date: 50.days.ago, end_date: 20.days.from_now) }
  let_it_be(:child_epic_b) { create(:epic, group: group, title: 'Child epic B', description: markdown, parent: epic, start_date: 100.days.ago, end_date: 10.days.from_now, labels: [label1]) }
  let_it_be(:child_issue_a) { create(:epic_issue, epic: epic, issue: public_issue, relative_position: 1) }

  before do
    group.add_developer(user)
    stub_licensed_features(epics: true, subepics: true)
    sign_in(user)
  end

  def add_existing_issue
    button_name = 'Add an existing issue'

    page.within('.related-items-tree-container') do
      click_button 'Add'
      click_button button_name
      fill_in "Enter issue URL", with: '#'
      wait_for_requests
    end
  end

  def add_existing_epic
    button_name = 'Add an existing epic'

    page.within('.related-items-tree-container') do
      click_button 'Add'
      click_button button_name
      fill_in "Enter epic URL", with: '&'
      wait_for_requests
    end
  end

  def open_colors_dropdown
    page.within('aside.right-sidebar [data-testid="colors-select"]') do
      click_button 'Edit'
    end
  end

  describe 'when sub-epics feature is available' do
    before do
      visit group_epic_path(group, epic)
    end

    describe 'Epic metadata' do
      it 'shows buttons `Tree view` and `Roadmap view`' do
        expect(find_by_testid('tree-view-button')).to have_content('Tree view')
        expect(find_by_testid('roadmap-view-button')).to have_content('Roadmap view')
      end
    end

    describe 'Epics and Issues tab' do
      it 'shows Related items tree with child epics' do
        page.within('.js-epic-container') do
          expect(page).to have_selector('.related-items-tree-container')

          page.within('.related-items-tree-container') do
            expect(page.find('.issue-count-badge', text: '2')).to be_present
            expect(find('.tree-item:nth-child(1) .sortable-link')).to have_content('Child epic B')
            expect(find('.tree-item:nth-child(2) .sortable-link')).to have_content('Child epic A')
          end
        end
      end

      it 'toggles epic labels' do
        within_testid('related-items-container') do
          expect(find('.tree-item:nth-child(1)')).to have_selector('.gl-label')

          toggle_labels = find_by_testid('show-labels-toggle')

          toggle_labels.find('button').click

          wait_for_requests

          expect(find('.tree-item:nth-child(1)')).not_to have_selector('.gl-label')
        end
      end

      it 'autocompletes issues when "#" is input in the add item form', :aggregate_failures do
        add_existing_issue
        page.within('#atwho-ground-add-related-issues-form-input') do
          expect(page).to have_selector('#at-view-issues', visible: true)
          expect(page).not_to have_selector('#at-view-epics')
          expect(page).to have_selector('.atwho-view-ul li', count: 1)
        end
      end

      it 'autocompletes epics when "&" is input in the add item form', :aggregate_failures do
        add_existing_epic
        page.within('#atwho-ground-add-related-issues-form-input') do
          expect(page).not_to have_selector('#at-view-issues')
          expect(page).to have_selector('#at-view-epics', visible: true)
          expect(page).to have_selector('.atwho-view-ul li', count: 5)
        end
      end
    end

    describe 'Roadmap tab' do
      before do
        click_button 'Roadmap view'
        wait_for_requests
      end

      it 'shows Roadmap timeline with child epics' do
        page.within('.related-items-tree-container #roadmap') do
          expect(page).to have_selector('.roadmap-container .js-roadmap-shell')

          page.within('.js-roadmap-shell .epics-list-section') do
            expect(page).not_to have_content(not_child.title)
            expect(find('.epic-item-container:nth-child(1) .epics-list-item .epic-title')).to have_content('Child epic B')
            expect(find('.epic-item-container:nth-child(2) .epics-list-item .epic-title')).to have_content('Child epic A')
          end
        end
      end

      it 'does not show thread filter dropdown' do
        expect(find('#notes')).to have_selector('.js-discussion-filter-container', visible: false)
      end

      it 'has no limit on container width' do
        expect(find('.roadmap-container')[:class]).not_to include('container-limited')
      end
    end

    it 'switches between Epics and Issues tab and Roadmap tab when clicking on tab links' do
      click_button 'Roadmap view'
      wait_for_all_requests

      page.within('.related-items-tree-container') do
        expect(page).to have_selector('#roadmap', visible: true)
        expect(page).not_to have_selector('[data-testid="related-items-tree"]')
      end

      click_button 'Tree view'
      wait_for_all_requests

      page.within('.related-items-tree-container') do
        expect(page).to have_selector('[data-testid="related-items-tree"]', visible: true)
        expect(page).not_to have_selector('#roadmap')
      end
    end
  end

  describe 'when the sub-epics feature is not available' do
    before do
      stub_licensed_features(epics: true, subepics: false)
      visit group_epic_path(group, epic)
    end

    describe 'Epic metadata' do
      it 'shows epic tab `Issues`' do
        page.within('.related-items-tree-container') do
          expect(find('h3.gl-new-card-title')).to have_content('Issues')
        end
      end

      it 'does not show buttons `Tree view` and `Roadmap view`' do
        expect(find('.related-items-tree-container')).not_to have_content('Tree view')
        expect(find('.related-items-tree-container')).not_to have_content('Roadmap view')
      end
    end

    describe 'Issues tab' do
      it 'shows Related items tree with child epics' do
        page.within('.related-items-tree-container') do
          expect(page.find('.issue-count-badge', text: '1')).to be_present
        end
      end
    end
  end

  describe 'Epic metadata' do
    before do
      visit group_epic_path(group, epic)
    end

    it_behaves_like 'page meta description', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nos commodius agimus. Ex rebus enim timiditas, non ex vocabulis nascitur. Ita...'

    it 'shows epic type, status, date and author in header' do
      within('.detail-page-header-body') do
        expect(page).to have_css('.gl-badge', text: 'Open')
        expect(page).to have_text('Epic')
        expect(page).to have_text('created')
        expect(page).to have_link('Rick Sanchez')
      end
    end

    it 'shows epic title and description' do
      page.within('.epic-page-container .detail-page-description') do
        expect(find('.title')).to have_content(epic_title)
        expect(find('.description .md')).to have_content('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nos commodius agimus. Ex rebus enim timiditas, non ex vocabulis nascitur. Ita prorsus, inquam; Duo Reges: constructio interrete.')
      end
    end

    it 'shows epic overview preferences dropdown' do
      page.within('#notes') do
        expect(find('#discussion-preferences-dropdown')).to have_content('Sort or filter')
      end
    end

    describe 'Sort dropdown' do
      let!(:notes) { create_list(:note, 2, noteable: epic) }

      context 'when sorted by `Oldest first`' do
        it 'shows comments in the correct order', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/403208' do
          items = all('.timeline-entry .timeline-discussion-body .note-text')
          expect(items[0]).to have_content(notes[0].note)
          expect(items[1]).to have_content(notes[1].note)
        end
      end

      context 'when sorted by `Newest first`' do
        before do
          within_testid('discussion-preferences') do
            click_button 'Sort or filter'
            click_button 'Newest first'
            wait_for_requests
          end
        end

        it 'shows comments in the correct order', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/390310' do
          items = all('.timeline-entry .timeline-discussion-body .note-text')
          expect(items[0]).to have_content(notes[1].note)
          expect(items[1]).to have_content(notes[0].note)
        end
      end
    end
  end

  describe 'Epic sidebar' do
    before do
      visit group_epic_path(group, epic)
    end

    describe 'Labels select' do
      context 'when dropdown is open' do
        before do
          page.within('aside.right-sidebar [data-testid="labels-select"]') do
            click_button 'Edit'
          end
        end

        it 'shows labels within the label dropdown' do
          page.within('.js-labels-list [data-testid="dropdown-content"]') do
            expect(page).to have_selector('li', count: 3)
          end
        end

        it 'shows checkmark next to label when label is clicked' do
          page.within('.js-labels-list [data-testid="dropdown-content"]') do
            click_button label1.title

            expect(find('li', text: label1.title)).to have_selector('.gl-icon', visible: true)
          end
        end

        it 'shows label create view when `Create group label` is clicked' do
          page.within('.js-labels-block') do
            click_button 'Create group label'

            expect(page).to have_field _('Label name')
          end
        end

        it 'creates new label using create view', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/446136' do
          page.within('.js-labels-block') do
            click_button 'Create group label'
            fill_in 'Label name', with: 'Test label'
            click_link 'Magenta-pink'
            click_button 'Create'
          end

          page.within('.js-labels-list [data-testid="dropdown-content"]') do
            expect(page).to have_selector('li', count: 4)
            expect(page).to have_content('Test label')
          end
        end

        it 'shows labels list view when `Cancel` button is clicked from create view' do
          page.within('.js-labels-block') do
            click_button 'Create group label'
            click_button 'Cancel'

            expect(page).to have_selector('.js-labels-list')
          end
        end

        it 'shows labels list view when back button is clicked from create view' do
          page.within('.js-labels-block') do
            click_button 'Create group label'
            click_button 'Go back'

            expect(page).to have_selector('.js-labels-list')
          end
        end
      end
    end

    describe 'Colors select' do
      it 'shows the color select dropdown' do
        expect(page).to have_selector('[data-testid="colors-select"]')
      end

      it 'opens dropdown when `Edit` is clicked' do
        open_colors_dropdown

        expect(page).to have_css('.js-colors-block .js-colors-list')
      end

      context 'when dropdown is open' do
        before do
          open_colors_dropdown
        end

        it 'shows colors within the color dropdown' do
          page.within('.js-colors-list [data-testid="dropdown-content"]') do
            expect(page).to have_selector('li', count: 5)
          end
        end

        it 'shows checkmark next to color after a new color has been selected' do
          page.within('.js-colors-list [data-testid="dropdown-content"]') do
            click_button 'Green'
          end

          open_colors_dropdown

          page.within('.js-colors-list [data-testid="dropdown-content"]') do
            expect(find('li', text: 'Green')).to have_selector('.gl-icon', visible: true)
          end
        end
      end
    end

    describe 'Ancestor widget' do
      it 'shows parent and ancestor epics' do
        page.within('aside.right-sidebar [data-testid="sidebar-ancestors"]') do
          expect(page).to have_link(ancestor_epic.title)
          expect(page).to have_link(parent_epic.title)
        end
      end
    end
  end

  describe 'epic actions' do
    describe 'when open' do
      context 'when clicking the top `Close epic` button', :aggregate_failures do
        let(:open_epic) { create(:epic, group: group) }

        before do
          visit group_epic_path(group, open_epic)
        end

        it 'can close an epic' do
          expect(page).to have_css('.gl-badge', text: 'Open')

          within '.detail-page-description' do
            click_button 'Epic actions'
            click_button 'Close epic'
          end

          expect(page).to have_css('.gl-badge', text: 'Closed')
        end
      end

      context 'when clicking the bottom `Close epic` button', :aggregate_failures do
        let(:open_epic) { create(:epic, group: group) }

        before do
          visit group_epic_path(group, open_epic)
        end

        it 'can close an epic' do
          expect(page).to have_css('.gl-badge', text: 'Open')

          within '.timeline-content-form' do
            click_button 'Close epic'
          end

          expect(page).to have_css('.gl-badge', text: 'Closed')
        end
      end
    end

    describe 'when closed' do
      context 'when clicking the top `Reopen epic` button', :aggregate_failures do
        let(:closed_epic) { create(:epic, group: group, state: 'closed') }

        before do
          visit group_epic_path(group, closed_epic)
        end

        it 'can reopen an epic' do
          expect(page).to have_css('.gl-badge', text: 'Closed')

          within '.detail-page-description' do
            click_button 'Epic actions'
            click_button 'Reopen epic'
          end

          expect(page).to have_css('.gl-badge', text: 'Open')
        end
      end

      context 'when clicking the bottom `Reopen epic` button', :aggregate_failures do
        let(:closed_epic) { create(:epic, group: group, state: 'closed') }

        before do
          visit group_epic_path(group, closed_epic)
        end

        it 'can reopen an epic' do
          expect(page).to have_css('.gl-badge', text: 'Closed')

          within '.timeline-content-form' do
            click_button 'Reopen epic'
          end

          expect(page).to have_css('.gl-badge', text: 'Open')
        end
      end
    end
  end
end
