# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseMonitoringHelper, feature_category: :plan_provisioning do
  using RSpec::Parameterized::TableSyntax

  let(:user) { build_stubbed(:user) }
  let(:license) { build_stubbed(:gitlab_license) }

  describe '#show_active_user_count_threshold_banner?' do
    subject { helper.show_active_user_count_threshold_banner? }

    where(
      :dot_com,
      :admin_section,
      :user_dismissed_callout,
      :license_nil,
      :user_can_admin_all_resources,
      :license_active_user_count_threshold_reached,
      :should_render
    ) do
      false | true  | false | false | true  | true  | true # Happy Path
      true  | true  | false | false | true  | true  | nil # ::Gitlab.com? is true
      false | false | false | false | true  | true  | nil # admin_section is false
      false | true  | true  | false | true  | true  | nil # user_dismissed_callout is true
      false | true  | false | true  | true  | true  | nil # license is nil
      false | true  | false | false | false | true  | false # user_can_admin_all_resources is false
      false | true  | false | false | true  | false | false # license_active_user_count_threshold_reached is false
    end

    with_them do
      before do
        allow(Gitlab).to receive(:com?).and_return(dot_com)
        allow(helper).to receive(:admin_section?).and_return(admin_section)
        allow(helper).to receive(:user_dismissed?)
          .with(Users::CalloutsHelper::ACTIVE_USER_COUNT_THRESHOLD).and_return(user_dismissed_callout)

        allow(user).to receive(:can_admin_all_resources?).and_return(user_can_admin_all_resources)
        allow(helper).to receive(:current_user).and_return(user)

        if license_nil
          allow(License).to receive(:current).and_return(nil)
        else
          allow(license).to receive(:active_user_count_threshold_reached?)
            .and_return(license_active_user_count_threshold_reached)
          allow(License).to receive(:current).and_return(license)
        end
      end

      it { is_expected.to be should_render }
    end
  end

  describe '#users_over_license' do
    subject { helper.users_over_license }

    before do
      allow(Gitlab).to receive(:com?).and_return(false)
      allow(License).to receive(:current).and_return(license)
      allow(license).to receive(:overage_with_historical_max).and_return(10)
    end

    it { is_expected.to eq(10) }

    context 'when in GitLab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      it 'returns 0 overage' do
        is_expected.to eq(0)
      end
    end

    context 'when license is not available' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'returns 0 overage' do
        is_expected.to eq(0)
      end
    end

    context 'when there is no overage' do
      before do
        allow(license).to receive(:overage_with_historical_max).and_return(0)
      end

      it 'returns 0 overage' do
        is_expected.to eq(0)
      end
    end
  end
end
