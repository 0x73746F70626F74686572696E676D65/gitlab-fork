# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class CreateDuoProService < ::GitlabSubscriptions::Trials::BaseCreateService
      private

      def after_lead_success_hook
        track_event('duo_pro_lead_creation_success')

        super
      end

      def after_lead_error_hook(_result)
        track_event('duo_pro_lead_creation_failure')

        super
      end

      def after_trial_success_hook
        track_event('duo_pro_trial_registration_success')

        super
      end

      def after_trial_error_hook(_result)
        track_event('duo_pro_trial_registration_failure')

        super
      end

      def lead_service_class
        GitlabSubscriptions::Trials::CreateDuoProLeadService
      end

      def apply_trial_service_class
        GitlabSubscriptions::Trials::ApplyDuoProService
      end

      def namespaces_eligible_for_trial
        Users::DuoProTrialEligibleNamespacesFinder.new(user).execute
      end

      def trial_user_params
        super.merge(
          {
            product_interaction: 'duo_pro_trial',
            preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
            opt_in: user.onboarding_status_email_opt_in
          }
        )
      end

      def track_event(action)
        Gitlab::InternalEvents.track_event(action, user: user, namespace: namespace)
      end
    end
  end
end
