# frozen_string_literal: true

module EE
  module Onboarding
    module Status
      REGISTRATION_TYPE = {
        free: 'free',
        trial: 'trial',
        invite: 'invite',
        subscription: 'subscription'
      }.freeze

      REGISTRATION_KLASSES = {
        REGISTRATION_TYPE[:free] => ::Onboarding::FreeRegistration,
        REGISTRATION_TYPE[:trial] => ::Onboarding::TrialRegistration,
        REGISTRATION_TYPE[:invite] => ::Onboarding::InviteRegistration,
        REGISTRATION_TYPE[:subscription] => ::Onboarding::SubscriptionRegistration
      }.freeze

      module ClassMethods
        def enabled?
          ::Gitlab::Saas.feature_available?(:onboarding)
        end
      end

      def self.prepended(base)
        base.singleton_class.prepend ClassMethods
      end

      attr_reader :registration_type

      # string delegations
      delegate :tracking_label, :product_interaction, to: :registration_type
      # translation delegations
      delegate :setup_for_company_label_text, to: :registration_type
      # predicate delegations
      delegate :redirect_to_company_form?, to: :registration_type

      def initialize(*)
        super

        @registration_type = calculate_registration_type_klass
      end

      def welcome_submit_button_text
        base_value = registration_type.welcome_submit_button_text

        return base_value if subscription? || invite?
        return _('Get started!') if oauth?

        # free, trial if not in oauth
        base_value
      end

      def continue_full_onboarding?
        !subscription? &&
          !invite? &&
          !oauth? &&
          enabled?
      end

      def joining_a_project?
        ::Gitlab::Utils.to_boolean(params[:joining_project], default: false)
      end

      def convert_to_automatic_trial?
        # TODO: Basically only free, but this logic may go away soon as we start the next step in
        # https://gitlab.com/gitlab-org/gitlab/-/issues/453979
        return false if invite? || subscription? || trial?

        setup_for_company?
      end

      def invite?
        user.onboarding_status_registration_type == REGISTRATION_TYPE[:invite]
      end

      def trial?
        return false unless enabled?

        user.onboarding_status_registration_type == REGISTRATION_TYPE[:trial]
      end

      def oauth?
        # During authorization for oauth, we want to allow it to finish.
        return false unless base_stored_user_location_path.present?

        base_stored_user_location_path == ::Gitlab::Routing.url_helpers.oauth_authorization_path
      end

      def preregistration_tracking_label
        # Trial registrations do not call this right now, so we'll omit it here from consideration.
        return ::Onboarding::InviteRegistration.tracking_label if params[:invite_email]
        return ::Onboarding::SubscriptionRegistration.tracking_label if subscription_from_stored_location?

        ::Onboarding::FreeRegistration.tracking_label
      end

      def setup_for_company?
        ::Gitlab::Utils.to_boolean(params.dig(:user, :setup_for_company), default: false)
      end

      def enabled?
        self.class.enabled?
      end

      def subscription?
        return false unless enabled?

        user.onboarding_status_registration_type == REGISTRATION_TYPE[:subscription]
      end

      def company_lead_product_interaction
        if initial_trial?
          ::Onboarding::TrialRegistration.product_interaction
        else
          # Due to this only being called in an area where only trials reach,
          # we can assume and not check for free/invite/subscription/etc here.
          'SaaS Trial - defaulted'
        end
      end

      def initial_trial?
        user.onboarding_status_initial_registration_type == REGISTRATION_TYPE[:trial]
      end

      def eligible_for_iterable_trigger?
        return false if trial?
        # The invite check coming first matters now in the case of a welcome form with company params
        # being received when the user is really an invite.
        # This covers the case for user being added to a group after they register, but
        # before they finish the welcome step.
        return true if invite?
        # skip company page because it already sends request to CustomersDot
        return false if redirect_to_company_form?

        # regular registration
        continue_full_onboarding?
      end

      def stored_user_location
        # side effect free look at devise store_location_for(:user)
        session['user_return_to']
      end

      private

      attr_reader :params, :session

      def calculate_registration_type_klass
        REGISTRATION_KLASSES.fetch(user&.onboarding_status_registration_type, ::Onboarding::FreeRegistration)
      end

      def subscription_from_stored_location?
        base_stored_user_location_path == ::Gitlab::Routing.url_helpers.new_subscriptions_path
      end

      def base_stored_user_location_path
        return unless stored_user_location

        URI.parse(stored_user_location).path
      end
    end
  end
end
