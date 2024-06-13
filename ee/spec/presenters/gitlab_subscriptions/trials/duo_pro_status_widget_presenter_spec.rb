# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoProStatusWidgetPresenter, :saas, feature_category: :acquisition do
  let(:user) { build(:user) }
  let_it_be(:group) { create(:group) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- https://gitlab.com/gitlab-org/gitlab/-/issues/467062
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: group) # rubocop:todo RSpec/FactoryBot/AvoidCreate -- https://gitlab.com/gitlab-org/gitlab/-/issues/467062
  end

  before do
    build(:gitlab_subscription, :ultimate, namespace: group)
  end

  describe '#attributes' do
    subject { described_class.new(group, user: user).attributes }

    specify do
      freeze_time do
        # set here to ensure no date barrier flakiness
        add_on_purchase.update!(expires_on: 60.days.from_now)

        duo_pro_trial_status_widget_data_attrs = {
          container_id: 'duo-pro-trial-status-sidebar-widget',
          widget_url:
            ::Gitlab::Routing.url_helpers.group_usage_quotas_path(group, anchor: 'code-suggestions-usage-tab'),
          trial_days_used: 1,
          trial_duration: 60,
          percentage_complete: 1.67
        }
        duo_pro_trial_status_popover_data_attrs = {
          days_remaining: 60,
          trial_end_date: 60.days.from_now.to_date
        }
        result = {
          duo_pro_trial_status_widget_data_attrs: duo_pro_trial_status_widget_data_attrs,
          duo_pro_trial_status_popover_data_attrs: duo_pro_trial_status_popover_data_attrs
        }

        is_expected.to eq(result)
      end
    end
  end

  describe '#eligible_for_widget?' do
    let(:duo_pro_trials_enabled) { true }
    let(:root_group) { group }
    let(:current_user) { user }

    before do
      stub_feature_flags(duo_pro_trials: duo_pro_trials_enabled)
    end

    subject { described_class.new(root_group, user: current_user).eligible_for_widget? }

    context 'with a duo pro trial add on' do
      it { is_expected.to be(true) }

      context 'with duo_pro_trials disabled' do
        let(:duo_pro_trials_enabled) { false }

        it { is_expected.to be(false) }
      end
    end

    context 'without a duo pro trial add on' do
      let(:root_group) { build(:group) }

      it { is_expected.to be(false) }
    end
  end
end
