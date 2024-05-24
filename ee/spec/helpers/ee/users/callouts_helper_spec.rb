# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::Users::CalloutsHelper do
  include Devise::Test::ControllerHelpers
  using RSpec::Parameterized::TableSyntax

  describe '#render_dashboard_ultimate_trial', :saas do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }

    let(:user) { namespace.owner }

    where(:owns_group_without_trial?, :show_ultimate_trial?, :user_default_dashboard?, :has_no_trial_or_paid_plan?, :should_render?) do
      true  | true  | true  | true  | true
      true  | true  | true  | false | false
      true  | true  | false | true  | false
      true  | false | true  | true  | false
      true  | true  | false | false | false
      true  | false | false | true  | false
      true  | false | true  | false | false
      true  | false | false | false | false
      false | true  | true  | true  | false
      false | true  | true  | false | false
      false | true  | false | true  | false
      false | false | true  | true  | false
      false | true  | false | false | false
      false | false | false | true  | false
      false | false | true  | false | false
      false | false | false | false | false
    end

    with_them do
      before do
        allow(helper).to receive(:show_ultimate_trial?) { show_ultimate_trial? }
        allow(helper).to receive(:user_default_dashboard?) { user_default_dashboard? }
        allow(user).to receive(:owns_group_without_trial?) { owns_group_without_trial? }

        unless has_no_trial_or_paid_plan?
          create(:gitlab_subscription, hosted_plan: ultimate_plan, namespace: namespace)
        end
      end

      it do
        if should_render?
          expect(helper).to receive(:render).with('shared/ultimate_trial_callout_content')
        else
          expect(helper).not_to receive(:render)
        end

        helper.render_dashboard_ultimate_trial(user)
      end
    end
  end

  describe '#render_two_factor_auth_recovery_settings_check' do
    let(:user_two_factor_disabled) { create(:user) }
    let(:user_two_factor_enabled) { create(:user, :two_factor) }
    let(:anonymous) { nil }

    where(:kind_of_user, :is_gitlab_com?, :dismissed_callout?, :should_render?) do
      :anonymous                | false | false | false
      :anonymous                | true  | false | false
      :user_two_factor_disabled | false | false | false
      :user_two_factor_disabled | true  | false | false
      :user_two_factor_disabled | true  | true  | false
      :user_two_factor_enabled  | false | false | false
      :user_two_factor_enabled  | true  | false | true
      :user_two_factor_enabled  | true  | true  | false
    end

    with_them do
      before do
        user = send(kind_of_user)
        allow(helper).to receive(:current_user).and_return(user)
        allow(Gitlab).to receive(:com?).and_return(is_gitlab_com?)
        allow(user).to receive(:dismissed_callout?).and_return(dismissed_callout?) if user
      end

      it do
        if should_render?
          expect(helper).to receive(:render).with('shared/two_factor_auth_recovery_settings_check')
        else
          expect(helper).not_to receive(:render)
        end

        helper.render_two_factor_auth_recovery_settings_check
      end
    end
  end

  describe '.show_new_user_signups_cap_reached?' do
    subject { helper.show_new_user_signups_cap_reached? }

    let(:user) { create(:user) }
    let(:admin) { create(:user, admin: true) }

    context 'when user is anonymous' do
      before do
        allow(helper).to receive(:current_user).and_return(nil)
      end

      it { is_expected.to eq(false) }
    end

    context 'when user is not an admin' do
      before do
        allow(helper).to receive(:current_user).and_return(user)
      end

      it { is_expected.to eq(false) }
    end

    context 'when feature flag is enabled', :do_not_mock_admin_mode_setting do
      where(:new_user_signups_cap, :active_user_count, :result) do
        nil | 10 | false
        10  | 9  | false
        0   | 10 | true
        1   | 1  | true
      end

      with_them do
        before do
          allow(helper).to receive(:current_user).and_return(admin)
          allow(User.billable).to receive(:count).and_return(active_user_count)
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:new_user_signups_cap).and_return(new_user_signups_cap)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#dismiss_two_factor_auth_recovery_settings_check' do
    let_it_be(:user) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'dismisses `TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK` callout' do
      expect(::Users::DismissCalloutService)
        .to receive(:new)
        .with(
          container: nil,
          current_user: user,
          params: { feature_name: described_class::TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK }
        )
        .and_call_original

      helper.dismiss_two_factor_auth_recovery_settings_check
    end
  end

  describe '#show_verification_reminder?' do
    subject { helper.show_verification_reminder? }

    let_it_be(:user) { create(:user) }
    let_it_be(:pipeline) { create(:ci_pipeline, user: user, failure_reason: :user_not_verified) }

    where(:on_gitlab_com?, :logged_in?, :unverified?, :failed_pipeline?, :not_dismissed_callout?, :result) do
      true  | true  | true  | true  | true  | true
      false | true  | true  | true  | true  | false
      true  | false | true  | true  | true  | false
      true  | true  | false | true  | true  | false
      true  | true  | true  | false | true  | false
      true  | true  | true  | true  | false | false
    end

    with_them do
      before do
        allow(Gitlab).to receive(:com?).and_return(on_gitlab_com?)
        allow(helper).to receive(:current_user).and_return(logged_in? ? user : nil)
        allow(user).to receive(:has_valid_credit_card?).and_return(!unverified?)
        pipeline.update!(failure_reason: nil) unless failed_pipeline?
        allow(user).to receive(:dismissed_callout?).and_return(!not_dismissed_callout?)
      end

      it { is_expected.to eq(result) }
    end

    describe 'dismissing the alert timing' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
        allow(helper).to receive(:current_user).and_return(user)
        create(:callout, user: user, feature_name: :verification_reminder, dismissed_at: Time.current)
        create(:ci_pipeline, user: user, failure_reason: :user_not_verified, created_at: pipeline_created_at)
      end

      context 'when failing a pipeline after dismissing the alert' do
        let(:pipeline_created_at) { 2.days.from_now }

        it { is_expected.to eq(true) }
      end

      context 'when dismissing the alert after failing a pipeline' do
        let(:pipeline_created_at) { 2.days.ago }

        it { is_expected.to eq(false) }
      end
    end

    context 'when both ci_require_credit_card_on_free_plan and ci_require_credit_card_on_trial_plan are disabled' do
      before do
        stub_feature_flags(
          ci_require_credit_card_on_free_plan: false,
          ci_require_credit_card_on_trial_plan: false
        )

        allow(Gitlab).to receive(:com?).and_return(true)
        allow(helper).to receive(:current_user).and_return(user)
        create(:ci_pipeline, user: user, failure_reason: :user_not_verified)
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#web_hook_disabled_dismissed?', feature_category: :webhooks do
    let_it_be(:user, refind: true) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'with a group' do
      let_it_be(:group) { create(:group) }
      let(:factory) { :group_callout }
      let(:container_key) { :group }
      let(:container) { group }
      let(:key) { "web_hooks:last_failure:group-#{group.id}" }

      include_examples 'CalloutsHelper#web_hook_disabled_dismissed shared examples'
    end
  end

  describe '.show_joining_a_project_alert?', feature_category: :onboarding do
    where(:cookie_present?, :onboarding?, :user_dismissed_callout?, :expected_result) do
      true | true | true | false
      false | true | true | false
      true | false | true | false
      true | true | false | true
    end

    with_them do
      before do
        cookies[:signup_with_joining_a_project] = cookie_present?
        allow(::Gitlab::Saas).to receive(:feature_available?).with(:onboarding).and_return(onboarding?)
        allow(helper).to receive(:user_dismissed?).and_return(user_dismissed_callout?)
      end

      subject { helper.show_joining_a_project_alert? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '.show_transition_to_jihu_callout?', :do_not_mock_admin_mode_setting do
    let_it_be(:admin) { create(:user, :admin) }
    let_it_be(:user) { create(:user) }

    subject { helper.show_transition_to_jihu_callout? }

    using RSpec::Parameterized::TableSyntax

    where(:gitlab_com_subscriptions_enabled, :gitlab_jh, :has_active_license, :current_user, :timezone, :user_dismissed, :expected_result) do
      false | false | false | ref(:admin) | 'Asia/Hong_Kong'      | false | true
      false | false | false | ref(:admin) | 'Asia/Shanghai'       | false | true
      false | false | false | ref(:admin) | 'Asia/Macau'          | false | true
      false | false | false | ref(:admin) | 'Asia/Chongqing'      | false | true

      true  | false | false | ref(:admin) | 'Asia/Shanghai'       | false | false
      false | true  | false | ref(:admin) | 'Asia/Shanghai'       | false | false
      false | false | true  | ref(:admin) | 'Asia/Shanghai'       | false | false
      false | false | false | ref(:user)  | 'Asia/Shanghai'       | false | false
      false | false | false | ref(:admin) | 'America/Los_Angeles' | false | false
      false | false | false | ref(:admin) | 'Asia/Shanghai'       | true  | false
    end

    with_them do
      before do
        stub_saas_features(gitlab_com_subscriptions: gitlab_com_subscriptions_enabled)
        allow(::Gitlab).to receive(:jh?).and_return(gitlab_jh)
        allow(helper).to receive(:has_active_license?).and_return(has_active_license)
        allow(helper).to receive(:current_user).and_return(current_user)
        allow(helper).to receive(:user_dismissed?).with(::Users::CalloutsHelper::TRANSITION_TO_JIHU_CALLOUT) { user_dismissed }
        allow(current_user).to receive(:timezone).and_return(timezone)
      end

      it { is_expected.to be expected_result }
    end
  end
end
