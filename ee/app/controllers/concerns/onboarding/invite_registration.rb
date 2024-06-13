# frozen_string_literal: true

module Onboarding
  class InviteRegistration
    PRODUCT_INTERACTION = 'Invited User'
    private_constant :PRODUCT_INTERACTION
    TRACKING_LABEL = 'invite_registration'
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
      _('Get started!')
    end

    # predicate methods

    def self.redirect_to_company_form?
      false
    end
  end
end
