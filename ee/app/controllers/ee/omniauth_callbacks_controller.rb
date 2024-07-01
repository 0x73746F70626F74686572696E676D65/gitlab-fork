# frozen_string_literal: true

module EE
  module OmniauthCallbacksController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include ::Gitlab::RackLoadBalancingHelpers
    end

    override :openid_connect
    def openid_connect
      if License.feature_available?(:oidc_client_groups_claim)
        omniauth_flow(::Gitlab::Auth::Oidc)
      else
        super
      end
    end

    private

    override :log_failed_login
    def log_failed_login(author, provider)
      unauth_author = ::Gitlab::Audit::UnauthenticatedAuthor.new(name: author)
      user = ::User.new(id: unauth_author.id, name: author)
      ::Gitlab::Audit::Auditor.audit({
        name: "omniauth_login_failed",
        author: unauth_author,
        scope: user,
        target: user,
        additional_details: {
          failed_login: provider.upcase,
          author_name: user.name,
          target_details: user.name
        },
        message: "#{provider.upcase} login failed"
      })
    end

    override :perform_registration_tasks
    def perform_registration_tasks(user, provider)
      # This also protects the sub classes group saml and ldap from staring onboarding
      # as we don't want those to onboard.
      if provider.to_sym.in?(::AuthHelper.providers_for_base_controller)
        ::Onboarding::StatusCreateService
          .new(
            request.env.fetch('omniauth.params', {}).deep_symbolize_keys, session, user, onboarding_first_step_path
          ).execute
        clear_memoization(:onboarding_status) # clear since registration_type is now set

        # We need to do this here since the subscription flow relies on what was set in the stored_location_for(:user)
        # that was set on initial redirect from the SubscriptionsController#new and super will wipe that out.
        # Then the RegistrationsIdentityVerificationController#success will get
        # whatever is set in super instead of the subscription path we desire.
        super unless onboarding_status.subscription?
      else
        super
      end
    end

    def onboarding_params
      # The sign in path for creating an account with sso will not have params as there are no
      # leads that would start out there. So we need to protect for that here by using fetch
      request.env.fetch('omniauth.params', {}).slice('glm_source', 'glm_content', 'trial')
    end

    override :sign_in_and_redirect_or_verify_identity
    def sign_in_and_redirect_or_verify_identity(user, auth_user, new_user)
      return super if user.blocked? # When `block_auto_created_users` is set to true
      return super unless auth_user.signup_identity_verification_enabled?(user)
      return super if !new_user && user.signup_identity_verified?

      service_class = ::Users::EmailVerification::SendCustomConfirmationInstructionsService
      service_class.new(user).execute if new_user
      session[:verification_user_id] = user.id
      load_balancer_stick_request(::User, :user, user.id)

      redirect_to signup_identity_verification_path
    end

    override :set_session_active_since
    def set_session_active_since(id)
      ::Gitlab::Auth::Saml::SsoState.new(provider_id: id).update_active
    end

    override :store_redirect_to
    def store_redirect_to
      return unless ::Feature.enabled?(:ff_require_saml_auth_to_approve)

      redirect_to = request.env.dig('omniauth.params', 'redirect_to').presence
      redirect_to = sanitize_redirect redirect_to

      return unless redirect_to
      return unless valid_gitlab_initiated_saml_request?

      store_location_for :redirect, redirect_to
    end

    def saml_response
      oauth.fetch(:extra, {}).fetch(:response_object, {})
    end

    def valid_gitlab_initiated_saml_request?
      ::Gitlab::Auth::Saml::OriginValidator.new(session).gitlab_initiated?(saml_response)
    end
  end
end
