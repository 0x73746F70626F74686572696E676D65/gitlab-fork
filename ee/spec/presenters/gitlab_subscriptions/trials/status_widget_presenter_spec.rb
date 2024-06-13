# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::StatusWidgetPresenter, :saas, feature_category: :acquisition do
  describe '#attributes' do
    specify do
      freeze_time do
        # set here to ensure no date barrier flakiness
        group = build(:group) do |g|
          build(
            :gitlab_subscription,
            :active_trial, :ultimate_trial, namespace: g, trial_starts_on: Time.current, trial_ends_on: 30.days.from_now
          )
        end

        trial_status_widget_data_attrs = {
          container_id: 'trial-status-sidebar-widget',
          plan_name: 'Ultimate Trial',
          plans_href:
            ::Gitlab::Routing.url_helpers.group_billings_path(group),
          trial_days_used: 1,
          trial_duration: 30,
          percentage_complete: 3.33,
          trial_discover_page_path: ::Gitlab::Routing.url_helpers.group_discover_path(group),
          nav_icon_image_path: ActionController::Base.helpers.image_path('illustrations/gitlab_logo.svg')
        }
        trial_status_popover_data_attrs = {
          days_remaining: 30,
          trial_end_date: 30.days.from_now.to_date
        }
        result = {
          trial_status_widget_data_attrs: trial_status_widget_data_attrs,
          trial_status_popover_data_attrs: trial_status_popover_data_attrs
        }

        expect(described_class.new(group).attributes).to eq(result)
      end
    end
  end

  describe '#eligible_for_widget?' do
    let(:group) { build(:group) }

    before do
      build(
        :gitlab_subscription,
        :active_trial, :free, namespace: group, trial_starts_on: Time.current, trial_ends_on: 30.days.from_now
      )
    end

    subject { described_class.new(group).eligible_for_widget? }

    it { is_expected.to be(true) }

    it 'returns true when a free group is between day 1 and day 10 after trial ends' do
      travel_to(35.days.from_now) do
        is_expected.to be(true)
      end
    end

    it 'returns false when a free group has passed day 10 after trial ends' do
      travel_to(45.days.from_now) do
        is_expected.to be(false)
      end
    end
  end
end
