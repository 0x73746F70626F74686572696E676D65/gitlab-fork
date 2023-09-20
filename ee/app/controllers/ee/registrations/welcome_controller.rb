# frozen_string_literal: true

module EE
  module Registrations
    module WelcomeController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      prepended do
        include OneTrustCSP
        include GoogleAnalyticsCSP
        include GoogleSyndicationCSP
        include ::Onboarding::SetRedirect
        include RegistrationsTracking

        before_action only: :show do
          push_frontend_feature_flag(:gitlab_gtm_datalayer, type: :ops)
        end
      end

      private

      override :update_params
      def update_params
        super.merge(params.require(:user).permit(:registration_objective))
      end

      def passed_through_params
        opt_in_param = {
          opt_in: ::Gitlab::Utils.to_boolean(params[:opt_in_to_email], default: onboarding_status.setup_for_company?)
        }

        update_params.slice(:role, :registration_objective)
                     .merge(params.permit(:jobs_to_be_done_other))
                     .merge(glm_tracking_params)
                     .merge(params.permit(:trial))
                     .merge(opt_in_param)
      end

      def iterable_params
        {
          provider: 'gitlab',
          work_email: current_user.email,
          uid: current_user.id,
          comment: params[:jobs_to_be_done_other],
          jtbd: update_params[:registration_objective],
          product_interaction: onboarding_status.iterable_product_interaction,
          opt_in: ::Gitlab::Utils.to_boolean(params[:opt_in_to_email], default: false)
        }.merge(update_params.slice(:setup_for_company, :role).to_h.symbolize_keys)
      end

      override :successful_update_hooks
      def successful_update_hooks
        finish_onboarding(current_user) unless onboarding_status.continue_full_onboarding?

        return unless onboarding_status.eligible_for_iterable_trigger?

        ::Onboarding::CreateIterableTriggerWorker.perform_async(iterable_params)
      end

      override :signup_onboarding_path
      def signup_onboarding_path
        if onboarding_status.joining_a_project?
          finish_onboarding(current_user)
          path_for_signed_in_user(current_user)
        elsif onboarding_status.redirect_to_company_form?
          path = new_users_sign_up_company_path(passed_through_params)
          save_onboarding_step_url(path, current_user)
          path
        else
          path = new_users_sign_up_group_path
          save_onboarding_step_url(path, current_user)
          path
        end
      end

      override :track_event
      def track_event(action)
        ::Gitlab::Tracking.event(
          helpers.body_data_page,
          action,
          user: current_user,
          label: onboarding_status.tracking_label
        )
      end

      override :welcome_update_params
      def welcome_update_params
        glm_tracking_params.merge(params.permit(:trial))
      end
    end
  end
end
