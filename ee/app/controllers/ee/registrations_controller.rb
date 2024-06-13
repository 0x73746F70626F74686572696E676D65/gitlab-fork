# frozen_string_literal: true

module EE
  module RegistrationsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize
    include ::Users::IdentityVerificationHelper
    include ::Gitlab::Tracking::Helpers::InvalidUserErrorEvent

    prepended do
      include Arkose::ContentSecurityPolicy
      include Arkose::TokenVerifiable
      include RegistrationsTracking
      include GoogleAnalyticsCSP
      include GoogleSyndicationCSP

      skip_before_action :check_captcha, if: -> { arkose_labs_enabled? }
      before_action :restrict_registration, only: [:new, :create]
      before_action :ensure_can_remove_self, only: [:destroy]
      before_action :verify_arkose_labs_challenge!, only: :create
    end

    override :new
    def new
      super

      ::Gitlab::Tracking.event(
        self.class.name,
        'render_registration_page',
        label: preregistration_tracking_label
      )
    end

    override :destroy
    def destroy
      unless allow_account_deletion?
        redirect_to profile_account_path, status: :see_other, alert: s_('Profiles|Account deletion is not allowed.')
        return
      end

      super
    end

    private

    def verify_arkose_labs_challenge!
      return if verify_arkose_labs_token

      flash[:alert] =
        s_('Session|There was a error loading the user verification challenge. Refresh to try again.')

      render action: 'new'
    end

    def restrict_registration
      return unless restricted_country?(request.env['HTTP_CF_IPCOUNTRY'], invite_root_namespace)
      return if allow_invited_user?

      member&.destroy
      redirect_to restricted_signup_identity_verification_path
    end

    def allow_invited_user?
      return false unless invite_root_namespace

      invite_root_namespace.paid? || invite_root_namespace.trial?
    end

    def invite_root_namespace
      member&.source&.root_ancestor
    end
    strong_memoize_attr :invite_root_namespace

    def member
      member_id = session[:originating_member_id]
      return unless member_id

      ::Member.find_by_id(member_id)
    end
    strong_memoize_attr :member

    def exempt_paid_namespace_invitee_from_identity_verification(user)
      return unless identity_verification_enabled?
      return unless invite_root_namespace&.has_subscription?
      return unless invite_root_namespace&.actual_plan&.paid_excluding_trials?

      user.create_identity_verification_exemption('invited to paid namespace')
    end

    override :after_successful_create_hook
    def after_successful_create_hook(user)
      # The order matters here as the arkose call needs to come before the devise action happens.
      # In that devise create action the user.active_for_authentication? call needs to return false so that
      # RegistrationsController#after_inactive_sign_up_path_for is correctly called with the custom_attributes
      # that are added by this action so that the IdentityVerifiable module observation of them is correct.
      # Identity Verification feature specs cover this ordering.
      record_arkose_data(user)

      # calling this before super since originating_member_id will be cleared from the session when super is called
      exempt_paid_namespace_invitee_from_identity_verification(user)

      super

      send_custom_confirmation_instructions

      service = PhoneVerification::Users::RateLimitService
      service.assume_user_high_risk_if_daily_limit_exceeded!(user)

      ::Onboarding::StatusCreateService
        .new(onboarding_status_params, session, resource, onboarding_first_step_path).execute
      clear_memoization(:onboarding_status) # clear since registration_type is now set

      log_audit_event(user)
      # This must come after user has been onboarding to properly detect the label from the onboarded user.
      ::Gitlab::Tracking.event(
        self.class.name,
        'successfully_submitted_form',
        label: onboarding_status.tracking_label,
        user: user
      )

      return unless params[:signup_intent].present?

      experiment(:signup_intent_step_one, actor: user)
        .track(params[:signup_intent], label: onboarding_status.tracking_label)
    end

    override :set_resource_fields
    def set_resource_fields
      super

      custom_confirmation_instructions_service.set_token(save: false)
    end

    override :identity_verification_enabled?
    def identity_verification_enabled?
      resource.signup_identity_verification_enabled?
    end

    override :identity_verification_redirect_path
    def identity_verification_redirect_path
      signup_identity_verification_path
    end

    def send_custom_confirmation_instructions
      return unless identity_verification_enabled?

      custom_confirmation_instructions_service.send_instructions
    end

    def custom_confirmation_instructions_service
      ::Users::EmailVerification::SendCustomConfirmationInstructionsService.new(resource)
    end
    strong_memoize_attr :custom_confirmation_instructions_service

    def ensure_can_remove_self
      unless current_user&.can_remove_self?
        redirect_to profile_account_path,
          status: :see_other,
          alert: s_('Profiles|Account could not be deleted. GitLab was unable to verify your identity.')
      end
    end

    def log_audit_event(user)
      ::Gitlab::Audit::Auditor.audit({
        name: "registration_created",
        author: user,
        scope: user,
        target: user,
        target_details: user.username,
        message: _("Instance access request"),
        additional_details: {
          registration_details: user.registration_audit_details
        }
      })
    end

    override :registration_path_params
    def registration_path_params
      glm_tracking_params.to_h
    end

    def record_arkose_data(user)
      return unless arkose_labs_enabled?(user: user)
      return unless arkose_labs_verify_response

      track_arkose_challenge_result

      Arkose::RecordUserDataService.new(
        response: arkose_labs_verify_response,
        user: user
      ).execute
    end

    override :arkose_labs_enabled?
    def arkose_labs_enabled?(user: nil)
      ::Arkose::Settings.enabled?(user: user, user_agent: request.user_agent)
    end

    override :preregistration_tracking_label
    def preregistration_tracking_label
      onboarding_status.preregistration_tracking_label
    end

    override :track_error
    def track_error(new_user)
      super
      track_invalid_user_error(new_user, preregistration_tracking_label)
    end

    def allow_account_deletion?
      !License.feature_available?(:disable_deleting_account_for_users) ||
        ::Gitlab::CurrentSettings.allow_account_deletion?
    end

    def username
      sign_up_params[:username]
    end
  end
end
