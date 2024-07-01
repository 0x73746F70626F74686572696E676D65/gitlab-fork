# frozen_string_literal: true

module Onboarding
  class TrialRegistration
    PRODUCT_INTERACTION = 'SaaS Trial'
    private_constant :PRODUCT_INTERACTION
    TRACKING_LABEL = 'trial_registration'
    private_constant :TRACKING_LABEL

    # string methods

    def self.tracking_label
      TRACKING_LABEL
    end

    def self.product_interaction
      PRODUCT_INTERACTION
    end

    # internalization methods

    def self.welcome_submit_button_text
      _('Continue')
    end

    def self.setup_for_company_label_text
      _('Who will be using this GitLab trial?')
    end

    # predicate methods

    def self.redirect_to_company_form?
      true
    end
  end
end
