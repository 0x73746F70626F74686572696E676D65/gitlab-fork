# frozen_string_literal: true

module Users
  class IdentityVerificationController < BaseIdentityVerificationController
    before_action :ensure_feature_enabled
    before_action :ensure_challenge_completed!, only: [:send_phone_verification_code]

    def show
      session[:identity_verification_referer] = request.referer
    end

    def success
      redirect_url = session.delete(:identity_verification_referer) || root_path
      redirect_to redirect_url
    end

    private

    def ensure_feature_enabled
      return not_found unless ::Feature.enabled?(:opt_in_identity_verification, @user, type: :wip)

      not_found unless ::Gitlab::Saas.feature_available?(:identity_verification)
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
