# frozen_string_literal: true

# EE:SaaS
# TODO: namespace https://gitlab.com/gitlab-org/gitlab/-/issues/338394
class TrialRegistrationsController < RegistrationsController
  extend ::Gitlab::Utils::Override

  include ::Onboarding::SetRedirect
  include OneTrustCSP
  include BizibleCSP
  include GoogleAnalyticsCSP
  include GoogleSyndicationCSP

  layout 'minimal'

  skip_before_action :require_no_authentication_without_flash

  before_action :verify_onboarding_enabled!
  before_action :redirect_to_trial, only: [:new], if: :user_signed_in?

  feature_category :onboarding

  override :new
  def new
    @resource = Users::AuthorizedBuildService.new(nil, {}).execute

    ::Gitlab::Tracking.event(
      self.class.name,
      'render_registration_page',
      label: preregistration_tracking_label
    )
  end

  private

  def redirect_to_trial
    redirect_to new_trial_path(request.query_parameters)
  end

  override :after_sign_up_path
  def after_sign_up_path
    ::Gitlab::Utils.add_url_parameters(super, { trial: true })
  end

  override :onboarding_first_step_path
  def onboarding_first_step_path
    ::Gitlab::Utils.add_url_parameters(super, { trial: true })
  end

  override :onboarding_status_params
  def onboarding_status_params
    super.merge(trial: true)
  end

  override :sign_up_params_attributes
  def sign_up_params_attributes
    [:first_name, :last_name, :username, :email, :password]
  end

  override :resource
  def resource
    @resource ||= Users::AuthorizedBuildService.new(current_user, sign_up_params).execute
  end

  override :preregistration_tracking_label
  def preregistration_tracking_label
    ::Onboarding::TrialRegistration.tracking_label
  end
end

TrialRegistrationsController.prepend_mod
