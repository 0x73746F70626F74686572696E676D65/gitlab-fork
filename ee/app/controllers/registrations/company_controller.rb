# frozen_string_literal: true

module Registrations
  class CompanyController < ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include GoogleSyndicationCSP
    include RegistrationsTracking
    include ::Onboarding::SetRedirect

    layout 'minimal'

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user!
    feature_category :onboarding

    helper_method :onboarding_status

    def new
      track_event('render')
    end

    def create
      result = GitlabSubscriptions::CreateCompanyLeadService.new(user: current_user, params: permitted_params).execute

      if result.success?
        track_event('successfully_submitted_form')

        response = Onboarding::StatusStepUpdateService
                     .new(current_user, new_users_sign_up_group_path(glm_tracking_params)).execute

        redirect_to response[:step_url]
      else
        flash.now[:alert] = result.errors.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    private

    def permitted_params
      params.permit(
        :company_name,
        :company_size,
        :first_name,
        :last_name,
        :phone_number,
        :country,
        :state,
        :website_url,
        # passed through params
        :role,
        :registration_objective,
        :jobs_to_be_done_other
      ).merge(glm_tracking_params)
    end

    def track_event(action)
      ::Gitlab::Tracking.event(self.class.name, action, user: current_user, label: onboarding_status.tracking_label)
    end

    def onboarding_status
      ::Onboarding::Status.new(params.to_unsafe_h.deep_symbolize_keys, session, current_user)
    end
    strong_memoize_attr :onboarding_status
  end
end
