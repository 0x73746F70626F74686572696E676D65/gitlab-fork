# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Discovers > Hand Raise Lead', :js, :saas, feature_category: :activation do
  include Features::HandRaiseLeadHelpers

  let_it_be(:user) { create(:user, :with_namespace, organization: 'YMCA') }
  let_it_be(:group) do
    create(
      :group_with_plan, plan: :ultimate_trial_plan,
      trial_starts_on: Date.today, trial_ends_on: Date.tomorrow, owners: user
    )
  end

  before do
    stub_saas_features(subscriptions_trials: true)

    sign_in(user)

    visit group_discover_path(group)
  end

  context 'when user interacts with hand raise lead and submits' do
    it 'renders and submits the top of the page instance' do
      all_by_testid('trial-discover-hand-raise-lead-button').first.click

      fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'trial_discover_page')
    end

    it 'renders and submits the bottom of the page instance' do
      all_by_testid('trial-discover-hand-raise-lead-button').last.click

      fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'trial_discover_page')
    end
  end
end
