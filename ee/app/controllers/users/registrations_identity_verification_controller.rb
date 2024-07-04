# frozen_string_literal: true

module Users
  class RegistrationsIdentityVerificationController < BaseIdentityVerificationController
    include AcceptsPendingInvitations
    include ::Gitlab::Utils::StrongMemoize
    include ::Gitlab::InternalEventsTracking
    extend ::Gitlab::Utils::Override

    helper_method :onboarding_status

    skip_before_action :authenticate_user!

    before_action :require_unverified_user!, except: [:verification_state, :success, :restricted]
    before_action :require_arkose_verification!, except: [:arkose_labs_challenge, :verify_arkose_labs_session,
      :restricted]

    def show; end

    def arkose_labs_challenge; end

    def verify_arkose_labs_session
      unless verify_arkose_labs_token(user: @user)
        track_internal_event("fail_arkose_challenge_during_registration", user: @user)

        flash[:alert] = s_('IdentityVerification|Complete verification to sign up.')
        return render action: :arkose_labs_challenge
      end

      track_arkose_challenge_result

      service = PhoneVerification::Users::RateLimitService
      service.assume_user_high_risk_if_daily_limit_exceeded!(@user)

      redirect_to action: :show
    end

    def verify_email_code
      result = verify_token

      if result[:status] == :success
        confirm_user

        render json: { status: :success }
      else
        log_event(:email, :failed_attempt, result[:reason])

        render json: result
      end
    end

    def resend_email_code
      if send_rate_limited?
        render json: { status: :failure, message: rate_limited_error_message(:email_verification_code_send) }
      else
        reset_confirmation_token

        render json: { status: :success }
      end
    end

    def success
      return redirect_to signup_identity_verification_path unless @user.signup_identity_verified?

      accept_pending_invitations(user: @user)

      sign_in(@user)
      session.delete(:verification_user_id)

      # order matters here because set_redirect_url removes our ability to detect trial in the tracking label
      @tracking_label = onboarding_status.tracking_label

      set_redirect_url
      experiment(:phone_verification_for_low_risk_users, user: @user).track(:registration_completed)
    end

    private

    override :after_pending_invitations_hook
    def after_pending_invitations_hook
      ::Onboarding::StatusConvertToInviteService.new(@user, initial_registration: true).execute
    end

    def require_unverified_user!
      redirect_to success_signup_identity_verification_path if @user.signup_identity_verified?
    end

    def find_verification_user
      return unless session[:verification_user_id]

      verification_user_id = session[:verification_user_id]
      load_balancer_stick_request(::User, :user, verification_user_id)
      User.find_by_id(verification_user_id)
    end

    def require_arkose_verification!
      return unless arkose_labs_enabled?
      return unless @user.identities.any?
      return if @user.arkose_verified?

      redirect_to action: :arkose_labs_challenge
    end

    def verify_token
      ::Users::EmailVerification::ValidateTokenService.new(
        attr: :confirmation_token,
        user: @user,
        token: params.require(:registrations_identity_verification).permit(:code)[:code]
      ).execute
    end

    def confirm_user
      @user.confirm
      log_event(:email, :success)
    end

    def reset_confirmation_token
      service = ::Users::EmailVerification::GenerateTokenService.new(attr: :confirmation_token, user: @user)
      token, encrypted_token = service.execute
      @user.update!(confirmation_token: encrypted_token, confirmation_sent_at: Time.current)
      Notify.confirmation_instructions_email(@user.email, token: token).deliver_later
      log_event(:email, :sent_instructions)
    end

    def send_rate_limited?
      ::Gitlab::ApplicationRateLimiter.throttled?(:email_verification_code_send, scope: @user)
    end

    def onboarding_status
      Onboarding::Status.new(params.to_unsafe_h.deep_symbolize_keys, session, @user)
    end
    strong_memoize_attr :onboarding_status

    def set_redirect_url
      @redirect_url = if onboarding_status.subscription?
                        # Since we need this value to stay in the stored_location_for(user) in order for
                        # us to be properly redirected for subscription signups.
                        onboarding_status.stored_user_location
                      else
                        after_sign_in_path_for(@user)
                      end
    end

    def required_params
      params.require(controller_name.to_sym)
    end
  end
end
