# frozen_string_literal: true

module Onboarding
  class SubscriptionRegistration
    TRACKING_LABEL = 'subscription_registration'
    private_constant :TRACKING_LABEL

    # string methods

    def self.tracking_label
      TRACKING_LABEL
    end

    # internalization methods

    def self.welcome_submit_button_text
      _('Continue')
    end

    def self.setup_for_company_label_text
      _('Who will be using this GitLab subscription?')
    end

    # predicate methods

    def self.redirect_to_company_form?
      false
    end
  end
end
