# frozen_string_literal: true

module Registrations
  class WelcomeController < ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include GoogleSyndicationCSP
    include ::Gitlab::Utils::StrongMemoize
    include ::Onboarding::Redirectable
    include ::Onboarding::SetRedirect
    include RegistrationsTracking

    layout 'minimal'

    before_action :verify_onboarding_enabled!

    helper_method :onboarding_status

    feature_category :onboarding

    def show
      return redirect_to path_for_signed_in_user if completed_welcome_step?

      # We need to perform cookie migration for variant assignment from logged out to log in
      # calling this in the controller layer gives us access to request where the
      # signed cookie exist with the info we need for migration.
      experiment(:signup_intent_step_one, actor: current_user).run

      experiment(:signup_intent_step_one, actor: current_user)
        .track(:render_welcome, label: onboarding_status.tracking_label)

      track_event('render')
    end

    def update
      result = ::Users::SignupService.new(current_user, update_params).execute

      if result.success?
        clear_memoization(:onboarding_status) # needed in case registration_type is changed on update
        track_event('successfully_submitted_form')
        track_joining_a_project_event
        successful_update_hooks

        redirect_to update_success_path
      else
        render :show
      end
    end

    private

    def authenticate_user!
      return if current_user

      redirect_to new_user_registration_path
    end

    def completed_welcome_step?
      !current_user.setup_for_company.nil?
    end

    def update_params
      # TODO: this is getting hit 3 times at least due to calls to it.
      # There likely isn't any perf impact, but should we look to memoize in a
      # future step in https://gitlab.com/gitlab-org/gitlab/-/issues/465532?
      params.require(:user)
            .permit(:role, :setup_for_company, :registration_objective, :onboarding_status_email_opt_in)
            .merge(onboarding_status_params)
    end

    def onboarding_status_params
      status_params = { onboarding_status_email_opt_in: parsed_opt_in }

      return status_params unless onboarding_status.convert_to_automatic_trial?

      # Now we are in automatic trial and we'll update our status as such, initial_registration_type
      # will be how we know if they weren't a trial originally from here on out.
      status_params
        .merge(onboarding_status_registration_type: ::Onboarding::StatusCreateService::REGISTRATION_TYPE[:trial])
    end

    def passed_through_params
      update_params.slice(:role, :registration_objective)
                   .merge(params.permit(:jobs_to_be_done_other))
                   .merge(glm_tracking_params)
    end

    def iterable_params
      {
        provider: 'gitlab',
        work_email: current_user.email,
        uid: current_user.id,
        comment: params[:jobs_to_be_done_other],
        jtbd: update_params[:registration_objective],
        product_interaction: onboarding_status.iterable_product_interaction,
        opt_in: current_user.onboarding_status_email_opt_in,
        preferred_language: ::Gitlab::I18n.trimmed_language_name(current_user.preferred_language)
      }.merge(update_params.slice(:setup_for_company, :role).to_h.symbolize_keys)
    end

    def update_success_path
      if onboarding_status.continue_full_onboarding? # trials/regular registration on .com
        signup_onboarding_path
      elsif onboarding_status.single_invite? # invites w/o tasks due to order
        flash[:notice] = helpers.invite_accepted_notice(onboarding_status.last_invited_member)
        polymorphic_path(onboarding_status.last_invited_member_source)
      else
        # Subscription registrations goes through here as well.
        # Invites will come here too if there is more than 1.
        path_for_signed_in_user
      end
    end

    def successful_update_hooks
      ::Onboarding::FinishService.new(current_user).execute unless onboarding_status.continue_full_onboarding?

      return unless onboarding_status.eligible_for_iterable_trigger?

      ::Onboarding::CreateIterableTriggerWorker.perform_async(iterable_params) # rubocop:disable CodeReuse/Worker
    end

    def signup_onboarding_path
      if onboarding_status.joining_a_project?
        Onboarding::FinishService.new(current_user).execute
        path_for_signed_in_user
      elsif onboarding_status.redirect_to_company_form?
        Onboarding::StatusStepUpdateService
          .new(current_user, new_users_sign_up_company_path(passed_through_params)).execute[:step_url]
      else
        Onboarding::StatusStepUpdateService.new(current_user, new_users_sign_up_group_path).execute[:step_url]
      end
    end

    def parsed_opt_in
      return false if onboarding_status.invite? # order matters here as invites are treated differently
      # The below would override DOM setting, but DOM is interwoven with JS to hide the opt in checkbox if
      # setup for company is toggled, so this is where this is a bit complex to think about
      return true if onboarding_status.setup_for_company?

      ::Gitlab::Utils.to_boolean(params.dig(:user, :onboarding_status_email_opt_in), default: false)
    end

    def track_joining_a_project_event
      return unless onboarding_status.joining_a_project?

      cookies[:signup_with_joining_a_project] = { value: true, expires: 30.days }

      track_event('select_button', label: 'join_a_project')
    end

    def track_event(action, label: onboarding_status.tracking_label)
      ::Gitlab::Tracking.event(
        helpers.body_data_page,
        action,
        user: current_user,
        label: label
      )
    end

    def onboarding_status
      Onboarding::Status.new(params.to_unsafe_h.deep_symbolize_keys, session, current_user)
    end
    strong_memoize_attr :onboarding_status
  end
end

Registrations::WelcomeController.prepend_mod
