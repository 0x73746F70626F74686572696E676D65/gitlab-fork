# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial Widget in Sidebar', :saas, :js, feature_category: :acquisition do
  include Features::HandRaiseLeadHelpers

  let_it_be(:user) { create(:user, :with_namespace, organization: 'YMCA') }
  let_it_be(:group) do
    create(
      :group_with_plan, plan: :ultimate_trial_plan, trial_starts_on: Date.current, trial_ends_on: 30.days.from_now
    ) do |record|
      record.add_owner(user)
    end
  end

  before do
    stub_application_setting(check_namespace_plan: true)
    allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService, plan: :free) do |instance|
      allow(instance).to receive(:execute).and_return([{ 'code' => 'ultimate', 'id' => 'ultimate-plan-id' }])
    end

    sign_in(user)
  end

  context 'for the widget' do
    it 'shows the correct days used and remaining' do
      travel_to(15.days.from_now) do
        visit group_path(group)

        expect(page).to have_content('Ultimate Trial Day 15/30')
      end
    end

    context 'on the first day of trial' do
      it 'shows the correct days used' do
        freeze_time do
          visit group_path(group)

          expect(page).to have_content('Ultimate Trial Day 1/30')
        end
      end
    end

    context 'on the last day of trial' do
      it 'shows days used and remaining as the same' do
        travel_to(30.days.from_now) do
          visit group_path(group)

          expect(page).to have_content('Ultimate Trial Day 30/30')
        end
      end
    end
  end

  context 'for the popover' do
    context 'when in a group' do
      before do
        visit group_path(group)
      end

      it 'shows the popover for the trial status widget and submits hand raise lead' do
        expect(page).not_to have_selector('.js-sidebar-collapsed')

        find_by_testid('trial-widget-menu').hover

        within_testid('trial-status-popover') do
          expect(page).to have_content("We hope you’re enjoying the features of GitLab")

          find_by_testid('trial-popover-hand-raise-lead-button').click
        end

        fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'trial-status-show-group')
      end
    end

    context 'when in a project' do
      let_it_be(:project) { create(:project, namespace: group) }

      before do
        visit project_path(project)
      end

      it 'shows the popover for the trial status widget' do
        expect(page).not_to have_selector('.js-sidebar-collapsed')

        find_by_testid('trial-widget-menu').hover

        within_testid('trial-status-popover') do
          expect(page).to have_content("We hope you’re enjoying the features of GitLab")

          find_by_testid('trial-popover-hand-raise-lead-button').click
        end

        fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'trial-status-show-group')
      end
    end
  end
end
