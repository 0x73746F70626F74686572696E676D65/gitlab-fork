# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoProStatusWidgetBuilder, :saas, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: user) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: group)
  end

  describe '#widget_data_attributes' do
    subject { described_class.new(user, group).widget_data_attributes }

    specify do
      result = {
        container_id: 'duo-pro-trial-status-sidebar-widget',
        widget_url: ::Gitlab::Routing.url_helpers.group_usage_quotas_path(group, anchor: 'code-suggestions-usage-tab'),
        trial_days_used: 1,
        trial_duration: 60,
        percentage_complete: 1.67
      }

      is_expected.to eq(result)
    end
  end

  describe '#popover_data_attributes' do
    subject { described_class.new(user, group).popover_data_attributes }

    specify do
      freeze_time do
        # set here to ensure no date barrier flakiness
        add_on_purchase.update!(expires_on: 60.days.from_now)
        result = {
          purchase_now_url:
            ::Gitlab::Routing.url_helpers.group_usage_quotas_path(group, anchor: 'code-suggestions-usage-tab'),
          days_remaining: 60,
          trial_end_date: 60.days.from_now.to_date
        }

        is_expected.to eq(result)
      end
    end
  end

  describe '#show?' do
    let(:subscriptions_trials_enabled) { true }
    let(:duo_pro_trials_enabled) { true }
    let(:root_group) { group }
    let(:current_user) { user }

    before do
      stub_saas_features(subscriptions_trials: subscriptions_trials_enabled)
      stub_feature_flags(duo_pro_trials: duo_pro_trials_enabled)
    end

    subject { described_class.new(current_user, root_group).show? }

    context 'with a duo pro trial add on' do
      it { is_expected.to be(true) }

      context 'with duo_pro_trials disabled' do
        let(:duo_pro_trials_enabled) { false }

        it { is_expected.to be(false) }
      end

      context 'with subscription_trials not available' do
        let(:subscriptions_trials_enabled) { false }

        it { is_expected.to be(false) }
      end

      context 'when user can not administer the namespace' do
        let(:current_user) { create(:user) }

        it { is_expected.to be(false) }
      end

      context 'when namespace is not present' do
        let(:root_group) { nil }

        it { is_expected.to be(false) }
      end
    end

    context 'without a duo pro trial add on' do
      let(:root_group) { create(:group, owners: user) }

      it { is_expected.to be(false) }
    end
  end
end
