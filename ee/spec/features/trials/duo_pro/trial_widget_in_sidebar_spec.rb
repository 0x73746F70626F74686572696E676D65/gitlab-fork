# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Pro Trial Widget in Sidebar', :saas, :js, feature_category: :acquisition do
  include Features::HandRaiseLeadHelpers

  let_it_be(:user) { create(:user, :with_namespace, organization: 'YMCA') }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab', owners: user) }

  before_all do
    create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: group)
  end

  before do
    stub_saas_features(subscriptions_trials: true)

    sign_in(user)
  end

  context 'for the widget' do
    it 'shows the correct days used and remaining' do
      travel_to(15.days.from_now) do
        visit group_path(group)

        expect_widget_title_to_be('GitLab Duo Pro Trial Day 15/60')
      end
    end

    context 'on the first day of trial' do
      it 'shows the correct days used' do
        freeze_time do
          visit group_path(group)

          expect_widget_title_to_be('GitLab Duo Pro Trial Day 1/60')
        end
      end
    end

    context 'on the last day of trial' do
      it 'shows days used and remaining as the same' do
        travel_to(60.days.from_now) do
          visit group_path(group)

          expect_widget_title_to_be('GitLab Duo Pro Trial Day 60/60')
        end
      end
    end

    def expect_widget_title_to_be(widget_title)
      within_testid(widget_menu_selector) do
        expect(page).to have_content(widget_title)
      end
    end
  end

  context 'for the popover' do
    context 'when in a group' do
      before do
        visit group_path(group)
      end

      it 'shows the popover for the widget' do
        expect(page).not_to have_selector('.js-sidebar-collapsed')

        find_by_testid(widget_menu_selector).hover

        expect_popover_content_to_be('To continue using features in GitLab Duo Pro')

        expect_launch_and_submit_hand_raise_lead_success
      end
    end

    context 'when in a project' do
      let_it_be(:project) { create(:project, namespace: group) }

      before do
        visit project_path(project)
      end

      it 'shows the popover for the widget' do
        expect(page).not_to have_selector('.js-sidebar-collapsed')

        find_by_testid(widget_menu_selector).hover

        expect_popover_content_to_be('To continue using features in GitLab Duo Pro')

        expect_launch_and_submit_hand_raise_lead_success
      end
    end

    def expect_popover_content_to_be(content)
      within_testid(popover_selector) do
        expect(page).to have_content(content)
      end
    end

    def popover_selector
      'duo-pro-trial-status-popover'
    end

    def expect_launch_and_submit_hand_raise_lead_success
      within_testid(popover_selector) do
        find_by_testid('duo-pro-trial-popover-hand-raise-lead-button').click
      end

      fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'duo-pro-trial-status-show-group')
    end
  end

  def widget_menu_selector
    'duo-pro-trial-widget-menu'
  end
end
