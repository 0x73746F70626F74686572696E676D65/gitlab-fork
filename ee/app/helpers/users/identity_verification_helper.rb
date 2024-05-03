# frozen_string_literal: true

module Users
  module IdentityVerificationHelper
    include RecaptchaHelper

    RESTRICTED_COUNTRY_CODES = %w[CN HK MO].freeze

    def signup_identity_verification_data(user)
      overrides = {
        phone_challenge_on_verify: true,
        phone_challenge_on_send: true,
        phone_enable_arkose_challenge: enable_arkose_challenge?(:phone),
        phone_show_arkose_challenge: show_arkose_challenge?(user, :phone),
        phone_show_recaptcha_challenge: show_recaptcha_challenge?,
        credit_card_challenge_on_verify: show_recaptcha_challenge?,
        credit_card_verify_captcha_path: signup_iv_action_path(:verify_credit_card_captcha)
      }

      build_data(user, path_helper: method(:signup_iv_action_path), overrides: overrides)
    end

    def identity_verification_data(user)
      overrides = {
        phone_challenge_on_send: true,
        phone_challenge_on_verify: false,
        phone_enable_arkose_challenge: true,
        phone_show_arkose_challenge: true,
        phone_show_recaptcha_challenge: false,
        credit_card_challenge_on_verify: false,
        arkose_data_exchange_payload: arkose_data_exchange_payload
      }

      build_data(user, path_helper: method(:iv_action_path), overrides: overrides)
    end

    def user_banned_error_message
      if ::Gitlab.com?
        format(
          _("Your account has been blocked. Contact %{support} for assistance."),
          support: EE::CUSTOMER_SUPPORT_URL
        )
      else
        _("Your account has been blocked. Contact your GitLab administrator for assistance.")
      end
    end

    def rate_limited_error_message(limit)
      interval_in_seconds = ::Gitlab::ApplicationRateLimiter.rate_limits[limit][:interval]
      interval = distance_of_time_in_words(interval_in_seconds)
      message = if limit == :email_verification_code_send
                  s_("IdentityVerification|You've reached the maximum amount of resends. " \
                     'Wait %{interval} and try again.')
                else
                  s_("IdentityVerification|You've reached the maximum amount of tries. " \
                     'Wait %{interval} and try again.')
                end

      format(message, interval: interval)
    end

    def enable_arkose_challenge?(category)
      return false unless category == :phone
      return false if show_recaptcha_challenge?

      Feature.enabled?(:arkose_labs_phone_verification_challenge)
    end

    def show_arkose_challenge?(user, category)
      enable_arkose_challenge?(category) &&
        PhoneVerification::Users::RateLimitService.verification_attempts_limit_exceeded?(user)
    end

    def show_recaptcha_challenge?
      recaptcha_enabled? &&
        PhoneVerification::Users::RateLimitService.daily_transaction_soft_limit_exceeded?
    end

    def restricted_country?(country_code, namespace = nil)
      return false unless ::Feature.enabled?(:prevent_registration_from_china, namespace, type: :gitlab_com_derisk)

      RESTRICTED_COUNTRY_CODES.include?(country_code)
    end

    private

    def build_data(user, path_helper:, overrides: {})
      {
        data: {
          verification_state_path: path_helper.call(:verification_state),
          phone_exemption_path: path_helper.call(:toggle_phone_exemption),
          phone_send_code_path: path_helper.call(:send_phone_verification_code),
          phone_verify_code_path: path_helper.call(:verify_phone_verification_code),
          credit_card_verify_path: path_helper.call(:verify_credit_card),
          successful_verification_path: path_helper.call(:success),
          offer_phone_number_exemption: user.offer_phone_number_exemption?,
          credit_card: credit_card_verification_data(user),
          phone_number: phone_number_verification_data(user),
          email: email_verification_data(user),
          arkose: arkose_labs_data
        }.merge(overrides).to_json
      }
    end

    def email_verification_data(user)
      {
        obfuscated: obfuscated_email(user.email),
        verify_path: verify_email_code_signup_identity_verification_path,
        resend_path: resend_email_code_signup_identity_verification_path
      }
    end

    def phone_number_verification_data(user)
      record = user.phone_number_validation
      return {} unless record

      {
        country: record.country,
        international_dial_code: record.international_dial_code,
        number: record.phone_number,
        send_allowed_after: record.sms_send_allowed_after
      }
    end

    def credit_card_verification_data(user)
      {
        user_id: user.id,
        form_id: ::Gitlab::SubscriptionPortal::REGISTRATION_VALIDATION_FORM_ID
      }
    end

    def signup_iv_action_path(action)
      iv_action_path(action, signup: true)
    end

    def iv_action_path(action, signup: false)
      # Paths for RegistrationsIdentityVerificationController actions are named
      # *signup_identity_verification_path while those for
      # IdentityVerificationController are named *identity_verification_path.
      # Since both controllers have the same action names this method makes it
      # easier to call a route helper method that points to either by providing
      # the action name and (optionally) a `sign_up` argument.
      route_helper_prefix = signup ? 'signup' : ''
      route_helper_name = [action.to_s, route_helper_prefix, 'identity_verification_path'].reject(&:blank?).join('_')
      public_send(route_helper_name) # rubocop:disable GitlabSecurity/PublicSend -- Call either *signup_identity_verification_path and *identity_verification_path route helpers
    end

    def arkose_data_exchange_payload
      Arkose::DataExchangePayload.new(
        request,
        use_case: Arkose::DataExchangePayload::USE_CASE_ACTIVE_USER,
        require_challenge: true
      ).build
    end
  end
end
