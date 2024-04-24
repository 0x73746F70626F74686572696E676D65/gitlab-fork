# frozen_string_literal: true

module Users
  class IdentityVerificationController < BaseIdentityVerificationController
    before_action :ensure_feature_enabled

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

    def required_params
      params.require(controller_name.to_sym)
    end
  end
end
