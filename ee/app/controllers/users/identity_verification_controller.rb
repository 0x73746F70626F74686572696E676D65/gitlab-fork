# frozen_string_literal: true

module Users
  class IdentityVerificationController < BaseIdentityVerificationController
    before_action :ensure_challenge_completed!, only: [:send_phone_verification_code]
    before_action :require_unverified_user!, except: [:success]

    def show
      session[:identity_verification_referer] = request.referer
    end

    def success
      redirect_to redirect_path
    end

    private

    def redirect_path
      @redirect_path ||= session.delete(:identity_verification_referer) || root_path
    end

    def require_unverified_user!
      redirect_to redirect_path if @user.identity_verified?
    end

    def ensure_challenge_completed!
      return if verify_arkose_labs_token

      message = s_('IdentityVerification|Complete verification to proceed.')
      render status: :bad_request, json: { message: message }
    end

    def required_params
      params.require(controller_name.to_sym)
    end
  end
end
