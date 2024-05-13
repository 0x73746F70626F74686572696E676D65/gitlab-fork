# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TrialStatusWidgetHelper, :saas, feature_category: :acquisition do
  describe 'data attributes for mounting Vue components', :freeze_time do
    let(:trial_length) { 30 } # days
    let(:trial_days_remaining) { 18 }
    let(:trial_days_used) { trial_length - trial_days_remaining }
    let(:trial_end_date) { Date.current.advance(days: trial_days_remaining) }
    let(:trial_start_date) { Date.current.advance(days: trial_days_remaining - trial_length) }
    let(:trial_percentage_complete) { (trial_length - trial_days_remaining) * 100 / trial_length }
    let(:trial_status) do
      subscription = build(
        :gitlab_subscription,
        :active_trial,
        namespace: group,
        trial_starts_on: trial_start_date,
        trial_ends_on: trial_end_date
      )

      GitlabSubscriptions::TrialStatus.new(subscription.trial_starts_on, subscription.trial_ends_on)
    end

    let_it_be(:group) { create(:group) }

    let(:shared_expected_attrs) do
      {
        container_id: 'trial-status-sidebar-widget',
        plan_name: 'Ultimate',
        plans_href: group_billings_path(group),
        trial_discover_page_path: group_discover_path(group)
      }
    end

    describe '#trial_status_popover_data_attrs' do
      let_it_be(:user) { create(:user) }

      before do
        allow(helper).to receive(:current_user).and_return(user)
      end

      subject(:data_attrs) { helper.trial_status_popover_data_attrs(trial_status) }

      it 'returns the needed data attributes for mounting the popover Vue component' do
        result = {
          days_remaining: trial_days_remaining,
          target_id: shared_expected_attrs[:container_id],
          trial_end_date: trial_end_date
        }

        expect(data_attrs).to match(result)
      end
    end

    describe '#trial_status_widget_data_attrs' do
      before do
        allow(helper).to receive(:image_path).and_return('/image-path/for-file.svg')
      end

      subject(:data_attrs) { helper.trial_status_widget_data_attrs(group, trial_status) }

      it 'returns the needed data attributes for mounting the widget Vue component' do
        expect(data_attrs).to match(
          shared_expected_attrs.merge(
            trial_days_used: trial_days_used,
            trial_duration: trial_length,
            nav_icon_image_path: '/image-path/for-file.svg',
            percentage_complete: trial_percentage_complete
          )
        )
      end
    end
  end

  describe '#show_trial_status_widget?' do
    let_it_be(:group) { build(:group) }
    let_it_be(:gitlab_subscription) do
      build(:gitlab_subscription, :active_trial, :free, namespace: group, trial_starts_on: Time.current,
        trial_ends_on: 30.days.from_now)
    end

    subject(:show_widget?) { helper.show_trial_status_widget?(group) }

    it 'returns true when a group is in active trial' do
      expect(show_widget?).to eq true
    end

    it 'returns true when a free group is between day 1 and day 10 after trial ends',
      time_travel_to: 35.days.from_now do
      expect(show_widget?).to eq true
    end

    it 'returns false when a free group has passed day 10 after trial ends',
      time_travel_to: 45.days.from_now do
      expect(show_widget?).to eq false
    end
  end
end
