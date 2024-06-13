# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Add Ons > Discover Duo Pro > Hand Raise Lead', :js, :saas, feature_category: :activation do
  include Features::HandRaiseLeadHelpers

  let_it_be(:user) { create(:user, :with_namespace, organization: 'GitLab') }
  let_it_be(:group) do
    create(:group_with_plan, plan: :ultimate_trial_plan, trial_starts_on: Date.today, trial_ends_on: Date.tomorrow,
      owners: user)
  end

  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :trial, namespace: group)
  end

  before do
    stub_saas_features(subscriptions_trials: true)

    sign_in(user)

    visit group_add_ons_discover_duo_pro_path(group)
  end

  context 'when user interacts with hand raise lead and submits' do
    it 'renders and submits the top of the page instance' do
      all_by_testid('discover-duo-pro-hand-raise-lead-button').first.click

      fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'discover-duo-pro')
    end

    it 'renders and submits the bottom of the page instance' do
      all_by_testid('discover-duo-pro-hand-raise-lead-button').last.click

      fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'discover-duo-pro')
    end
  end
end
