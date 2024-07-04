# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nav::GitlabDuoUsageSettingsPage, feature_category: :duo_chat do
  using RSpec::Parameterized::TableSyntax

  include ::Nav::GitlabDuoUsageSettingsPage

  let(:owner) { build_stubbed(:user, group_view: :security_dashboard) }
  let(:current_user) { owner }
  let(:group) { create(:group, :private) }

  describe '#show_gitlab_duo_usage_menu_item?' do
    where(:is_usage_quotas_enabled, :should_show_gitlab_duo_usage_app, :ff_enabled?, :result) do
      true  | true  | true  | true
      true  | true  | false | false
      true  | false | true  | false
      false | true  | true  | false
      false | true  | false | false
      false | false | true  | false
      false | false | false | false
    end

    with_them do
      before do
        if should_show_gitlab_duo_usage_app
          stub_saas_features(gitlab_com_subscriptions: true)
          stub_licensed_features(code_suggestions: true)
          add_on = create(:gitlab_subscription_add_on)
          create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
        end

        allow(group).to receive(:usage_quotas_enabled?) { is_usage_quotas_enabled }
        stub_feature_flags(gitlab_duo_usage_menu_item: ff_enabled?)
      end

      it { expect(show_gitlab_duo_usage_menu_item?(group)).to be(result) }
    end
  end

  describe '#show_gitlab_duo_usage_app?' do
    context 'on saas' do
      let(:another_group) { build(:group) }

      before do
        stub_licensed_features(code_suggestions: true)
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(group).to receive(:has_free_or_no_subscription?) { has_free_or_no_subscription? }
        create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: group_with_duo_pro)
      end

      context 'when hamilton_seat_management is enabled' do
        where(:has_free_or_no_subscription?, :group_with_duo_pro, :result) do
          true | ref(:another_group) | false
          false | ref(:another_group) | true
          true | ref(:group) | true
          false | ref(:group) | true
        end

        with_them do
          it { expect(show_gitlab_duo_usage_app?(group)).to eq(result) }

          context 'when feature not available' do
            before do
              stub_licensed_features(code_suggestions: false)
            end

            it { expect(show_gitlab_duo_usage_app?(group)).to be_falsy }
          end
        end
      end

      context 'when hamilton_seat_management is disabled' do
        before do
          stub_feature_flags(hamilton_seat_management: false)
        end

        where(:has_free_or_no_subscription?, :group_with_duo_pro, :result) do
          true  | ref(:another_group) | false
          false | ref(:another_group) | false
          true  | ref(:group)         | false
          false | ref(:group)         | false
        end

        with_them do
          it { expect(show_gitlab_duo_usage_app?(group)).to eq(result) }
        end
      end
    end

    context 'on self managed' do
      before do
        stub_licensed_features(code_suggestions: true)
        stub_saas_features(gitlab_com_subscriptions: false)
        stub_feature_flags(self_managed_code_suggestions: true)
      end

      it { expect(show_gitlab_duo_usage_app?(group)).to be_falsy }
    end
  end
end
