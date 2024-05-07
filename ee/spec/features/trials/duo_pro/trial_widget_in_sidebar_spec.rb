# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Pro Trial Widget in Sidebar', :saas, :js, feature_category: :acquisition do
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
        travel_to(30.days.from_now) do
          visit group_path(group)

          expect_widget_title_to_be('GitLab Duo Pro Trial Day 30/60')
        end
      end
    end

    def expect_widget_title_to_be(widget_title)
      within_testid('duo-pro-trial-widget-menu') do
        expect(page).to have_content(widget_title)
      end
    end
  end
end
