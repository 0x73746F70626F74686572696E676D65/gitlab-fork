# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Plan, feature_category: :subscription_management do
  describe '#paid?' do
    subject { plan.paid? }

    Plan.default_plans.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build("#{plan}_plan".to_sym) }

        it { is_expected.to be_falsey }
      end
    end

    Plan::PAID_HOSTED_PLANS.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build("#{plan}_plan".to_sym) }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '::PLANS_ELIGIBLE_FOR_TRIAL' do
    subject { ::Plan::PLANS_ELIGIBLE_FOR_TRIAL }

    it { is_expected.to eq(%w[default free]) }
  end

  describe '.with_subscriptions' do
    it 'includes plans that have attached subscriptions', :saas do
      group = create(:group_with_plan, plan: :free_plan)
      create(:premium_plan)
      create(:ultimate_plan)

      expect(described_class.with_subscriptions).to match_array([group.gitlab_subscription.hosted_plan])
    end
  end

  describe '.by_namespace' do
    it 'includes plans that have attached subscriptions', :saas do
      group = create(:group_with_plan, plan: :free_plan)
      another_group = create(:group_with_plan, plan: :premium_plan)
      create(:ultimate_plan)

      expect(described_class.with_subscriptions.by_namespace([another_group, group]))
        .to match_array([group.gitlab_subscription.hosted_plan, another_group.gitlab_subscription.hosted_plan])
    end
  end

  describe '.by_distinct_names' do
    it 'includes distinct plan names', :saas do
      free_plan = create(:free_plan)
      free_group = create(:group_with_plan, plan: :free_plan)
      another_free_group = create(:group_with_plan, plan: :free_plan)
      create(:premium_plan)
      not_found_premium_group = create(:group_with_plan, plan: :premium_plan)
      ultimate_plan = create(:ultimate_plan)
      ultimate_group = create(:group_with_plan, plan: :ultimate_plan)

      namespaces = [free_group, another_free_group, not_found_premium_group, ultimate_group]
      expect(described_class.with_subscriptions.by_namespace(namespaces).by_distinct_names(%w[free ultimate]))
        .to match_array([free_plan, ultimate_plan])
    end
  end

  describe '#paid_excluding_trials?' do
    subject { plan.paid_excluding_trials? }

    real_paid_plans = Plan::PAID_HOSTED_PLANS - Plan::FREE_TRIAL_PLANS

    Plan.default_plans.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build("#{plan}_plan".to_sym) }

        it { is_expected.to be_falsey }
      end
    end

    real_paid_plans.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build("#{plan}_plan".to_sym) }

        it { is_expected.to be_truthy }
      end
    end

    Plan::FREE_TRIAL_PLANS.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build("#{plan}_plan".to_sym) }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#open_source?' do
    subject { plan.open_source? }

    context 'when is opensource' do
      let(:plan) { build(:opensource_plan) }

      it { is_expected.to be_truthy }
    end

    context 'when is not opensource' do
      let(:plan) { build(:free_plan) }

      it { is_expected.to be_falsey }
    end
  end
end
