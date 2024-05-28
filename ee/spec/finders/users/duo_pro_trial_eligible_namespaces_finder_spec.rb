# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::DuoProTrialEligibleNamespacesFinder, feature_category: :subscription_management do
  describe '#execute', :saas do
    let_it_be(:user) { create :user }
    let_it_be(:namespace_with_paid_plan) { create(:group_with_plan, name: 'Zed', plan: :ultimate_plan) }
    let_it_be(:namespace_with_duo_pro) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:namespace_with_other_addon) { create(:group_with_plan, name: 'Alpha', plan: :ultimate_plan) }
    let_it_be(:namespace_with_middle_name) { create(:group_with_plan, name: 'Beta', plan: :ultimate_plan) }
    let_it_be(:namespace_with_free_plan) { create(:group_with_plan, plan: :free_plan) }

    before_all do
      create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, namespace: namespace_with_duo_pro)
      create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: namespace_with_other_addon)
    end

    subject(:execute) { described_class.new(user).execute }

    context 'when the add-on does not exist in the system' do
      it { is_expected.to eq [] }
    end

    context 'when the add-on exists in the system' do
      context 'when user does not own groups' do
        it { is_expected.to eq [] }
      end

      context 'when user owns groups' do
        before_all do
          namespace_with_paid_plan.add_owner(user)
          namespace_with_duo_pro.add_owner(user)
          namespace_with_free_plan.add_owner(user)
          namespace_with_other_addon.add_owner(user)
          namespace_with_middle_name.add_owner(user)
        end

        it { is_expected.to eq [namespace_with_other_addon, namespace_with_middle_name, namespace_with_paid_plan] }
      end
    end
  end
end
