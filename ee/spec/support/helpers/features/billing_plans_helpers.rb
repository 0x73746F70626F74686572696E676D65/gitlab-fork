# frozen_string_literal: true

require_relative 'hand_raise_lead_helpers'

#  We write these in helper methods so that JH can override them
#  Related issue: https://gitlab.com/gitlab-org/gitlab/-/issues/361718
module Features
  module BillingPlansHelpers
    include HandRaiseLeadHelpers

    def should_have_hand_raise_lead_button
      expect(page).to have_selector(".js-hand-raise-lead-trigger", visible: false)
    end

    def click_premium_contact_sales_button_and_submit_form(user, namespace)
      within_testid('plan-card-premium') do
        click_button 'Contact sales'
      end

      fill_in_and_submit_hand_raise_lead(user, namespace, glm_content: 'billing-group')
    end
  end
end

Features::BillingPlansHelpers.prepend_mod
