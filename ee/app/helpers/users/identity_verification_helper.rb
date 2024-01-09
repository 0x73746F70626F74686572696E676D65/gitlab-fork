# frozen_string_literal: true

module Users
  module IdentityVerificationHelper
    include RecaptchaHelper

    def identity_verification_data(user)
      {
        data: {
          verification_state_path: verification_state_identity_verification_path,
          offer_phone_number_exemption: user.offer_phone_number_exemption?,
          phone_exemption_path: toggle_phone_exemption_identity_verification_path,
          credit_card: credit_card_verification_data(user),
          phone_number: phone_number_verification_data(user),
          email: email_verification_data(user),
          arkose: arkose_labs_data,
          successful_verification_path: success_identity_verification_path
        }.to_json
      }
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

    private

    def email_verification_data(user)
      {
        obfuscated: obfuscated_email(user.email),
        verify_path: verify_email_code_identity_verification_path,
        resend_path: resend_email_code_identity_verification_path
      }
    end

    def phone_number_verification_data(user)
      data = {
        send_code_path: send_phone_verification_code_identity_verification_path,
        verify_code_path: verify_phone_verification_code_identity_verification_path,
        enable_arkose_challenge: enable_arkose_challenge?(:phone).to_s,
        show_arkose_challenge: show_arkose_challenge?(user, :phone).to_s,
        show_recaptcha_challenge: show_recaptcha_challenge?.to_s
      }

      record = user.phone_number_validation
      return data unless record

      data.merge(
        {
          country: record.country,
          international_dial_code: record.international_dial_code,
          number: record.phone_number,
          send_allowed_after: record.sms_send_allowed_after
        }
      )
    end

    def credit_card_verification_data(user)
      {
        user_id: user.id,
        form_id: ::Gitlab::SubscriptionPortal::REGISTRATION_VALIDATION_FORM_ID,
        verify_credit_card_path: verify_credit_card_identity_verification_path,
        verify_captcha_path: verify_credit_card_captcha_identity_verification_path,
        show_recaptcha_challenge: show_recaptcha_challenge?.to_s
      }
    end
  end
end
