# frozen_string_literal: true

module Users
  class IdentityVerificationController < BaseIdentityVerificationController
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

    def required_params
      params.require(controller_name.to_sym)
    end
  end
end
