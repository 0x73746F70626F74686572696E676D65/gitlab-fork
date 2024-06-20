# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BillingPlansHelper, :saas, feature_category: :subscription_management do
  include Devise::Test::ControllerHelpers

  describe '#subscription_plan_data_attributes' do
    let(:group) { build(:group) }
    let(:customer_portal_url) { ::Gitlab::Routing.url_helpers.subscription_portal_manage_url }
    let(:subscription_portal_url) { ::Gitlab::Routing.url_helpers.subscription_portal_url }
    let(:add_seats_href) { "#{subscription_portal_url}/gitlab/namespaces/#{group.id}/extra_seats" }
    let(:plan_renew_href) { "#{subscription_portal_url}/gitlab/namespaces/#{group.id}/renew" }
    let(:billable_seats_href) { helper.group_usage_quotas_path(group, anchor: 'seats-quota-tab') }
    let(:refresh_seats_href) { helper.refresh_seats_group_billings_url(group) }
    let(:read_only) { true }

    let(:plan) do
      double('plan', id: 'external-paid-plan-hash-code', name: 'Bronze Plan')
    end

    context 'when group and plan with ID present' do
      let(:base_attrs) do
        {
          namespace_id: group.id,
          namespace_name: group.name,
          add_seats_href: add_seats_href,
          plan_renew_href: plan_renew_href,
          customer_portal_url: customer_portal_url,
          billable_seats_href: billable_seats_href,
          plan_name: plan.name,
          read_only: read_only.to_s,
          seats_last_updated: nil
        }
      end

      it 'returns data attributes' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
          .to eq(base_attrs.merge(refresh_seats_href: refresh_seats_href))
      end

      context 'with refresh_billings_seats feature flag off' do
        before do
          stub_feature_flags(refresh_billings_seats: false)
        end

        it 'returns data attributes' do
          expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
            .to eq(base_attrs)
        end
      end
    end

    context 'when group not present' do
      let(:group) { nil }

      it 'returns empty data attributes' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only)).to eq({})
      end
    end

    context 'when plan not present' do
      let(:plan) { nil }

      let(:base_attrs) do
        {
          add_seats_href: add_seats_href,
          billable_seats_href: billable_seats_href,
          customer_portal_url: customer_portal_url,
          namespace_id: nil,
          namespace_name: group.name,
          plan_renew_href: plan_renew_href,
          plan_name: nil,
          read_only: read_only.to_s,
          seats_last_updated: nil
        }
      end

      it 'returns attributes' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
          .to eq(base_attrs.merge(refresh_seats_href: refresh_seats_href))
      end

      context 'with refresh_billings_seats feature flag off' do
        before do
          stub_feature_flags(refresh_billings_seats: false)
        end

        it 'returns data attributes' do
          expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
            .to eq(base_attrs)
        end
      end
    end

    context 'when plan with ID not present' do
      let(:plan) { double('plan', id: nil, name: 'Bronze Plan') }

      let(:base_attrs) do
        {
          namespace_id: group.id,
          namespace_name: group.name,
          customer_portal_url: customer_portal_url,
          billable_seats_href: billable_seats_href,
          add_seats_href: add_seats_href,
          plan_renew_href: plan_renew_href,
          plan_name: plan.name,
          read_only: read_only.to_s,
          seats_last_updated: nil
        }
      end

      it 'returns data attributes without upgrade href' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
          .to eq(base_attrs.merge(refresh_seats_href: refresh_seats_href))
      end

      context 'with refresh_billings_seats feature flag off' do
        before do
          stub_feature_flags(refresh_billings_seats: false)
        end

        it 'returns data attributes' do
          expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
            .to eq(base_attrs)
        end
      end
    end

    context 'with different namespaces' do
      subject { helper.subscription_plan_data_attributes(namespace, plan) }

      context 'with namespace' do
        let(:namespace) { build(:namespace) }

        it 'does not return billable_seats_href' do
          expect(subject).not_to include(billable_seats_href: helper.group_usage_quotas_path(namespace, anchor: 'seats-quota-tab'))
        end
      end

      context 'with group' do
        let(:namespace) { build(:group) }

        it 'returns billable_seats_href for group' do
          expect(subject).to include(billable_seats_href: helper.group_usage_quotas_path(namespace, anchor: 'seats-quota-tab'))
        end
      end
    end

    context 'when seats_last_updated is being assigned' do
      let(:enqueue_time) { Time.new(2023, 2, 21, 12, 13, 14, "+00:00") }

      subject(:seats_last_updated) { helper.subscription_plan_data_attributes(group, plan, read_only: read_only)[:seats_last_updated] }

      context 'when the subscription has a last_seat_refresh_at' do
        let(:gitlab_subscription) { build(:gitlab_subscription, namespace: group, last_seat_refresh_at: enqueue_time) }

        before do
          allow(group).to receive(:gitlab_subscription).and_return(gitlab_subscription)
        end

        it { is_expected.to eq '12:13:14' }
      end

      context 'when no last_seat_refresh_at is available' do
        it { is_expected.to be nil }
      end
    end
  end

  describe '#can_edit_billing?' do
    let(:auditor_group) { build(:group) }
    let(:auditor) { create(:auditor) }
    let(:dev) { create(:user) }
    let(:admin) { create(:user, admin: true) }

    before do
      auditor_group.add_developer(dev)
      auditor_group.add_guest(auditor)
      auditor_group.add_owner(admin)
    end

    it 'is false for guest' do
      allow(helper).to receive(:current_user).and_return(auditor)

      expect(helper.can_edit_billing?(auditor_group)).to eq(false)
    end

    it 'is false for developer' do
      allow(helper).to receive(:current_user).and_return(dev)

      expect(helper.can_edit_billing?(auditor_group)).to eq(false)
    end

    it 'is true for admin' do
      allow(helper).to receive(:current_user).and_return(admin)

      expect(helper.can_edit_billing?(auditor_group)).to eq(true)
    end
  end

  describe '#show_contact_sales_button?' do
    using RSpec::Parameterized::TableSyntax

    where(:link_action, :result) do
      'upgrade' | true
      'no_upgrade' | false
    end

    with_them do
      subject { helper.show_contact_sales_button?(link_action) }

      it { is_expected.to eq(result) }
    end
  end

  describe '#show_upgrade_button?' do
    using RSpec::Parameterized::TableSyntax

    where(:link_action, :allow_upgrade, :result) do
      'upgrade'    | true  | true
      'upgrade'    | false | false
      'upgrade'    | nil   | true
      'no_upgrade' | true  | false
      'no_upgrade' | false | false
      'no_upgrade' | nil   | false
    end

    with_them do
      subject { helper.show_upgrade_button?(link_action, allow_upgrade) }

      it { is_expected.to eq(result) }
    end
  end

  describe '#plan_feature_list' do
    let(:plan_code) { 'ultimate' }
    let(:plan) { Hashie::Mash.new(code: plan_code) }

    let(:features_list) do
      Hashie::Mash.new({
        plan_code => [
          { title: s_('BillingPlans|All the benefits of Premium +'), highlight: true },
          { title: s_('BillingPlans|Company wide portfolio management') },
          { title: s_('BillingPlans|Advanced application security') },
          { title: s_('BillingPlans|Executive level insights') },
          { title: s_('BillingPlans|Compliance automation') },
          { title: s_('BillingPlans|Free guest users') },
          { title: s_('BillingPlans|50000 compute minutes') }
        ]
      })
    end

    it 'returns features list' do
      expect(helper.plan_feature_list(plan)).to eq(features_list[plan.code])
    end
  end

  describe '#plan_purchase_or_upgrade_url' do
    let(:plan) { double('Plan') }

    it 'is upgradable' do
      group = double(Group.sti_name, upgradable?: true)

      expect(helper).to receive(:plan_upgrade_url)

      helper.plan_purchase_or_upgrade_url(group, plan)
    end

    it 'is purchasable' do
      group = double(Group.sti_name, upgradable?: false)

      expect(helper).to receive(:plan_purchase_url)
      helper.plan_purchase_or_upgrade_url(group, plan)
    end
  end

  describe '#plan_purchase_url' do
    let_it_be(:group) { create(:group) }

    let(:plan) { double('Plan', id: 'plan-id') }

    before do
      stub_feature_flags(migrate_purchase_flows_for_existing_customers: false)
    end

    it 'builds correct gitlab url with some source' do
      user = create(:user)

      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:params).and_return({ source: 'some_source' })

      expect(helper.plan_purchase_url(group, plan))
        .to include "/-/subscriptions/new?namespace_id=#{group.id}&plan_id=plan-id&source=some_source"
    end

    it 'builds correct url for the old purchase flow' do
      user = create(:user, name: 'First')
      allow(helper).to receive(:current_user).and_return(user)

      expect(helper.plan_purchase_url(group, plan))
        .to eq("#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{group.id}&plan_id=plan-id")
    end
  end

  describe '#show_code_suggestions_card?' do
    let(:namespace) { build(:namespace) }

    subject { helper.show_code_suggestions_card?(namespace) }

    it { is_expected.to eq(true) }

    context 'when namespace has an active code suggestions add_on' do
      let(:namespace) { create(:gitlab_subscription_add_on_purchase, :active, :gitlab_duo_pro).namespace }

      it { is_expected.to eq(false) }
    end

    context 'when namespace has an expired code suggestions add_on' do
      let(:namespace) { create(:gitlab_subscription_add_on_purchase, :expired, :gitlab_duo_pro).namespace }

      it { is_expected.to eq(true) }
    end
  end

  describe '#upgrade_button_css_classes' do
    let(:plan_data) { double(deprecated?: plan_is_deprecated) }
    let(:namespace) do
      build(
        :group,
        gitlab_subscription: build(:gitlab_subscription, trial: trial_active, trial_ends_on: 1.week.from_now))
    end

    subject { helper.upgrade_button_css_classes(namespace, plan_data, is_current_plan) }

    before do
      allow(namespace.gitlab_subscription).to receive(:upgradable?).and_return(upgradable)
    end

    where(
      is_current_plan: [true, false],
      trial_active: [true, false],
      plan_is_deprecated: [true, false],
      upgradable: [true, false]
    )

    with_them do
      it 'returns the expected list of CSS classes' do
        expected_classes = [].tap do |ary|
          ary << 'disabled' if is_current_plan && !trial_active
          ary << 'invisible' if plan_is_deprecated
          ary << "billing-cta-purchase#{'-new' unless upgradable}"
        end.join(' ')

        is_expected.to eq(expected_classes)
      end
    end
  end

  describe '#billing_available_plans' do
    let(:plan) { double('Plan', deprecated?: false, code: 'premium', hide_deprecated_card?: false) }
    let(:deprecated_plan) { double('Plan', deprecated?: true, code: 'bronze', hide_deprecated_card?: false) }
    let(:plans_data) { [plan, deprecated_plan] }

    context 'when namespace is not on a plan' do
      it 'returns plans without deprecated' do
        expect(helper.billing_available_plans(plans_data, nil)).to eq([plan])
      end
    end

    context 'when namespace is on an active plan' do
      let(:current_plan) { double('plan', code: 'premium') }

      it 'returns plans without deprecated' do
        expect(helper.billing_available_plans(plans_data, nil)).to eq([plan])
      end
    end

    context 'when namespace is on a deprecated plan' do
      let(:current_plan) { double('plan', code: 'bronze') }

      it 'returns plans with a deprecated plan' do
        expect(helper.billing_available_plans(plans_data, current_plan)).to eq(plans_data)
      end
    end

    context 'when namespace is on a deprecated plan that has hide_deprecated_card set to true' do
      let(:current_plan) { double('plan', code: 'bronze') }
      let(:deprecated_plan) { double('Plan', deprecated?: true, code: 'bronze', hide_deprecated_card?: true) }

      it 'returns plans without the deprecated plan' do
        expect(helper.billing_available_plans(plans_data, current_plan)).to eq([plan])
      end
    end

    context 'when namespace is on a plan that has hide_deprecated_card set to true, but deprecated? is false' do
      let(:current_plan) { double('plan', code: 'premium') }
      let(:plan) { double('Plan', deprecated?: false, code: 'premium', hide_deprecated_card?: true) }

      it 'returns plans with the deprecated plan' do
        expect(helper.billing_available_plans(plans_data, current_plan)).to eq([plan])
      end
    end
  end

  describe '#subscription_plan_info' do
    it 'returns the current plan' do
      other_plan = Hashie::Mash.new(code: 'bronze')
      current_plan = Hashie::Mash.new(code: 'ultimate')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'ultimate')).to eq(current_plan)
    end

    it 'returns nil if no plan matches the code' do
      plan_a = Hashie::Mash.new(code: 'bronze')
      plan_b = Hashie::Mash.new(code: 'ultimate')

      expect(helper.subscription_plan_info([plan_a, plan_b], 'default')).to be_nil
    end

    it 'breaks a tie with the current_subscription_plan attribute if multiple plans have the same code' do
      other_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'premium')
      current_plan = Hashie::Mash.new(current_subscription_plan: true, code: 'premium')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'premium')).to eq(current_plan)
    end

    it 'returns nil if no plan matches the code even if current_subscription_plan is true' do
      other_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'free')
      current_plan = Hashie::Mash.new(current_subscription_plan: true, code: 'bronze')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'default')).to be_nil
    end

    it 'returns the plan matching the plan code even if current_subscription_plan is false' do
      other_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'bronze')
      current_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'premium')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'premium')).to eq(current_plan)
    end
  end

  describe '#show_plans?' do
    using RSpec::Parameterized::TableSyntax

    let(:group) { build(:group) }

    where(:free_personal, :trial_active, :gold_plan, :ultimate_plan, :opensource_plan, :expectations) do
      false | false | false | false | false | true
      false | true | false | false | false | true
      false | false | true | false | false | false
      false | true | true | false | false | true
      false | false | false | true | false | false
      false | true | false | true | false | true
      false | false | true | true | false | false
      false | true | true | true | false | true
      true | true | true | true | false | false
      false | false | false | false | true | false
    end

    with_them do
      before do
        allow(group).to receive(:free_personal?).and_return(free_personal)
        allow(group).to receive(:trial_active?).and_return(trial_active)
        allow(group).to receive(:gold_plan?).and_return(gold_plan)
        allow(group).to receive(:ultimate_plan?).and_return(ultimate_plan)
        allow(group).to receive(:opensource_plan?).and_return(opensource_plan)
      end

      it 'returns boolean' do
        expect(helper.show_plans?(group)).to eql(expectations)
      end
    end
  end

  describe '#show_start_free_trial_messages?' do
    using RSpec::Parameterized::TableSyntax

    let(:namespace) { build(:namespace) }

    where(:free_personal, :eligible_for_trial, :expected) do
      false | true | true
      true | true | false
      false | false | false
    end

    with_them do
      before do
        allow(namespace).to receive(:free_personal?).and_return(free_personal)
        allow(namespace).to receive(:eligible_for_trial?).and_return(eligible_for_trial)
      end

      it 'returns correct boolean value' do
        expect(helper.show_start_free_trial_messages?(namespace)).to eql(expected)
      end
    end
  end

  describe '#billing_upgrade_button_data' do
    let(:plan) { double('Plan', code: '_code_') }
    let(:data) do
      {
        track_action: 'click_button',
        track_label: 'upgrade',
        track_property: plan.code,
        testid: "upgrade-to-#{plan.code}"
      }
    end

    it 'has expected data' do
      expect(helper.billing_upgrade_button_data(plan)).to eq data
    end
  end

  describe '#start_free_trial_data' do
    let(:data) do
      {
        track_action: 'click_button',
        track_label: 'start_trial',
        testid: 'start-your-free-trial'
      }
    end

    it 'has expected data' do
      expect(helper.start_free_trial_data).to eq data
    end
  end

  describe '#add_namespace_plan_to_group_instructions' do
    let_it_be(:current_user) { create :user }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
    end

    context 'with maintained or owned group' do
      it 'instructs to move the project to a group' do
        create(:group).add_owner current_user

        expect(helper.add_namespace_plan_to_group_instructions).to eq 'Then <a href="/help/user/project/settings/index#transfer-a-project-to-another-namespace" target="_blank" rel="noopener noreferrer">move any projects</a> you wish to use with your subscription to that group.'
      end
    end

    context 'without a group' do
      it 'instructs to create a group then move the project to a group' do
        expect(helper.add_namespace_plan_to_group_instructions).to eq 'You don&#39;t have any groups. You&#39;ll need to <a href="/groups/new#create-group-pane">create one</a> and <a href="/help/user/project/settings/index#transfer-a-project-to-another-namespace" target="_blank" rel="noopener noreferrer">move your projects to it</a>.'
      end
    end
  end
end
