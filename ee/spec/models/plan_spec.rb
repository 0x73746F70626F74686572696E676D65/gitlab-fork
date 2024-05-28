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
