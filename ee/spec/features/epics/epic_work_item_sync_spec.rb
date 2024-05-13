# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic Work Item sync', :js, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:parent_epic) { create(:epic, group: group) }

  let(:description) { 'My synced epic' }
  let(:epic_title) { 'New epic' }
  let(:updated_title) { 'Another title' }
  let(:updated_description) { 'Updated description' }
  let(:start_date) { 1.day.after(Time.current).to_date }
  let(:due_date) { 5.days.after(start_date) }
  let(:description_input) do
    "#{description}\n/parent_epic #{parent_epic.to_reference}\n"
  end

  before_all do
    group.add_developer(user)
  end

  before do
    stub_licensed_features(epics: true, subepics: true, epic_colors: true)

    sign_in(user)
  end

  context 'when creating and modifying an epic' do
    subject(:create_epic) do
      visit new_group_epic_path(group)

      find_by_testid('epic-title-field').native.send_keys(epic_title)
      find_by_testid('markdown-editor-form-field').native.send_keys(description_input)
      find_by_testid('confidential-epic-checkbox').set(true)

      page.within(find_by_testid('epic-start-date')) do
        find_by_testid('gl-datepicker-input').native.send_keys(start_date.iso8601)
      end
      find('body').click
      send_keys(:tab) # make sure by tabbing that we no longer show the date picker

      page.within(find_by_testid('epic-due-date')) do
        find_by_testid('gl-datepicker-input').native.send_keys(due_date.iso8601)
      end
      find('body').click
      send_keys(:tab) # make sure by tabbing that we no longer show the date picker

      click_button 'Create epic'
    end

    it 'creates an epic and a synced work item' do
      # TODO: remove threshold after epic-work item sync
      # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(103)
      create_epic

      wait_for_requests

      epic = Epic.last

      expect(epic.title).to eq(epic_title)
      expect(epic.description).to eq(description)
      expect(epic).to be_confidential
      expect(epic.parent).to eq(parent_epic)
      expect(epic.start_date.iso8601).to eq(start_date.iso8601)
      expect(epic.due_date.iso8601).to eq(due_date.iso8601)

      expect(Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true).attributes).to be_empty
    end

    it 'updates the synced work item when the epic is updated' do
      # TODO: remove threshold after epic-work item sync
      # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(103)
      create_epic
      wait_for_requests
      epic = Epic.last

      find('.js-issuable-edit').click
      fill_in 'issuable-title', with: updated_title
      fill_in 'issue-description', with: updated_description

      click_button 'Save changes'
      wait_for_requests

      expect(epic.reload.title).to eq(updated_title)
      expect(epic.description).to eq(updated_description)

      page.within(find_by_testid('start-date')) do
        find_by_testid('reset-button').click
      end
      page.within(find_by_testid('due-date')) do
        find_by_testid('reset-button').click
      end

      page.within(find_by_testid('sidebar-confidentiality')) do
        find_by_testid('edit-button').click
        find_by_testid('confidential-toggle').click
      end

      page.within(find_by_testid('colors-select')) do
        find_by_testid('edit-button').click
        find_by_testid('dropdown-content').click_on 'Green'
      end

      wait_for_requests

      expect(epic.reload.start_date).to eq(nil)
      expect(epic.due_date).to eq(nil)
      expect(epic.reload).not_to be_confidential
      expect(epic.color.to_s).to eq('#217645')

      find_by_testid('close-reopen-button').click
      wait_for_requests
      expect(epic.reload).to be_closed
      expect(epic.work_item).to be_closed

      find_by_testid('close-reopen-button').click
      wait_for_requests
      expect(epic.reload).to be_open

      expect(Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true).attributes).to be_empty
    end

    context 'when updating description tasks' do
      let(:markdown) do
        <<-MARKDOWN.strip_heredoc
        This is a task list:

        - [ ] Incomplete entry 1
        - [ ] Incomplete entry 2
        MARKDOWN
      end

      let(:epic) { create(:epic, group: group, title: epic_title, description: markdown) }

      it 'syncs the updates to the work item' do
        visit group_epic_path(group, epic)

        expect(page).to have_selector('ul.task-list',      count: 1)
        expect(page).to have_selector('li.task-list-item', count: 2)
        expect(page).to have_selector('ul input[checked]', count: 0)

        find('.task-list .task-list-item', text: 'Incomplete entry 1').find('input').click

        wait_for_requests

        expect(page).to have_selector('ul input[checked]', count: 1)

        visit group_work_item_path(group, epic.work_item.iid)

        expect(page).to have_selector('li.task-list-item', count: 2)
        expect(page).to have_selector('ul input[checked]', count: 1)
      end
    end
  end
end
