# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic Work Item sync', :js, feature_category: :portfolio_management do
  include WorkItemFeedbackHelpers

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
    stub_feature_flags(synced_epic_work_item_editable: true)
    stub_licensed_features(epics: true, subepics: true, epic_colors: true)

    sign_in(user)
  end

  describe 'from epic to work item' do
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

    describe 'from work item to epic' do
      subject(:create_epic_work_item) do
        visit group_epics_path(group)
        find_by_testid('new-epic-button').click

        find_by_testid('title-input').fill_in with: epic_title
        find_by_testid('markdown-editor-form-field').native.send_keys(description_input)
        find_by_testid('confidential-checkbox').set(true)

        click_button 'Create epic'
      end

      it 'creates work item and a legacy epic that are in sync' do
        expect { create_epic_work_item }.to change { Epic.count }.by(1).and change { WorkItem.count }.by(1)

        wait_for_requests
        # We don't show the new epic work item in the list immediately.
        visit group_epics_path(group)
        expect(find('a', text: epic_title)).to be_visible

        work_item = WorkItem.last
        epic = work_item.synced_epic

        visit group_work_item_path(group, work_item.iid)
        expect(find_by_testid('work-item-title').text).to eq(work_item.title)

        expect(work_item.title).to eq(epic_title)
        expect(work_item.description).to eq(description)
        expect(work_item).to be_confidential
        expect(Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true).attributes).to be_empty
      end

      it 'updates the legacy epic when the work item is updated', :sidekiq_inline do
        create_epic_work_item
        wait_for_requests

        work_item = WorkItem.last
        visit group_work_item_path(group, work_item.iid)

        close_work_item_feedback_popover_if_present

        find_by_testid('work-item-edit-form-button').click
        find_by_testid('work-item-title-input').fill_in with: updated_title
        fill_in 'work-item-description', with: updated_description
        click_button 'Save changes'
        wait_for_requests

        find_by_testid('work-item-actions-dropdown').click
        find_by_testid('confidentiality-toggle-action').click
        wait_for_requests

        within(find_by_testid('work-item-rolledup-dates')) do
          click_button 'Edit'
        end
        fill_in('start-date-input', with: start_date.iso8601)
        fill_in('due-date-input', with: due_date.iso8601)
        find_by_testid('apply-button').click
        wait_for_requests

        find_by_testid('edit-color').click
        click_link('Dark red')
        wait_for_requests

        find_by_testid('edit-parent').click
        within_testid('work-item-parent-form') do
          set_parent(parent_epic.title)
        end

        work_item.reload
        epic = work_item.synced_epic

        expect(work_item.title).to eq(updated_title)
        expect(work_item.description).to eq(updated_description)
        expect(work_item).not_to be_confidential
        expect(work_item.work_item_parent).to eq(parent_epic.work_item)
        expect(work_item.color.color.to_s).to eq('#c91c00')

        expect(Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true).attributes).to be_empty
      end
    end

    def set_parent(parent_text)
      find('[data-testid="listbox-search-input"] .gl-listbox-search-input',
        visible: true).send_keys "\"#{parent_text}\""
      wait_for_requests

      find('.gl-new-dropdown-item', text: parent_text).click
      wait_for_all_requests
    end
  end
end
