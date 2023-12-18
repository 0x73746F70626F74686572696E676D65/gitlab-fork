# frozen_string_literal: true

module IdentityVerifiable
  include Gitlab::Utils::StrongMemoize
  include Gitlab::Experiment::Dsl
  extend ActiveSupport::Concern

  VERIFICATION_METHODS = {
    CREDIT_CARD: 'credit_card',
    PHONE_NUMBER: 'phone',
    EMAIL: 'email'
  }.freeze

  def identity_verification_enabled?
    return false unless ::Gitlab::CurrentSettings.email_confirmation_setting_hard?
    return false if ::Gitlab::CurrentSettings.require_admin_approval_after_user_signup

    email_wrapper = ::Gitlab::Email::FeatureFlagWrapper.new(email)
    Feature.enabled?(:identity_verification, email_wrapper)
  end

  def active_for_authentication?
    return false unless super

    !identity_verification_enabled? || identity_verified?
  end

  def identity_verified?
    return email_verified? unless identity_verification_enabled?

    # Treat users that have already signed in before as verified if their email
    # is already verified.
    #
    # This prevents the scenario where a user has to verify their identity
    # multiple times. For example:
    #
    # 1. identity_verification FF is enabled while
    # identity_verification_credit_card is disabled
    # 2. A user registers, is assigned High risk band, verifies their email as
    # prompted, and starts using GitLab
    # 3. identity_verification_credit_card FF is enabled
    # 4. User signs out and signs in again
    # 5. User is redirected to Identity Verification which requires them to
    # verify their credit card
    return email_verified? if last_sign_in_at.present?

    identity_verification_state.values.all?
  end

  def identity_verification_state
    # Return only the state of required verification methods instead of all
    # methods. This will save us from doing unnecessary queries. E.g. when risk
    # band is 'Low' we only need to call `confirmed?`
    required_identity_verification_methods.index_with do |method|
      verification_state[method].call
    end
  end
  strong_memoize_attr :identity_verification_state

  def required_identity_verification_methods
    return identity_verification_exempt_methods if exempt_from_identity_verification?
    return phone_number_exempt_methods if exempt_from_phone_number_verification?
    return assumed_high_risk_user_methods if high_risk_or_assumed_high_risk?

    risk_band_based_methods
  end

  def credit_card_verified?
    credit_card_validation.present? && !credit_card_validation.used_by_banned_user?
  end

  def arkose_risk_band
    risk_band_attr = custom_attributes.by_key(UserCustomAttribute::ARKOSE_RISK_BAND).first
    return unless risk_band_attr.present?

    risk_band_attr.value.downcase
  end

  def create_phone_number_exemption!
    custom_attributes.create!(
      key: UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT,
      value: true.to_s,
      user_id: id
    )
  end

  def destroy_phone_number_exemption
    !!phone_number_exemption_attribute && phone_number_exemption_attribute.destroy
  end

  def exempt_from_phone_number_verification?
    phone_number_exemption_attribute.present? &&
      ActiveModel::Type::Boolean.new.cast(phone_number_exemption_attribute.value)
  end

  def toggle_phone_number_verification
    exempt_from_phone_number_verification? ? destroy_phone_number_exemption : create_phone_number_exemption!
    clear_memoization(:phone_number_exemption_attribute)
    clear_memoization(:identity_verification_state)
  end

  def create_identity_verification_exemption
    custom_attributes.create(key: UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT, value: true)
  end

  def destroy_identity_verification_exemption
    identity_verification_exemption_attribute&.destroy
  end

  def exempt_from_identity_verification?
    identity_verification_exemption_attribute.present?
  end

  def offer_phone_number_exemption?
    return false unless credit_card_verification_enabled?

    case arkose_risk_band
    when Arkose::VerifyResponse::RISK_BAND_MEDIUM.downcase
      true
    when Arkose::VerifyResponse::RISK_BAND_LOW.downcase
      if phone_number_verification_enabled?
        experiment(:phone_verification_for_low_risk_users, user: self) do |e|
          e.candidate { true }
        end.run
      end
    else
      false
    end
  end

  def verification_method_allowed?(method:)
    return false unless verification_method_required?(method: method)

    # Take all methods that precede <method>. E.g. if <method> is cc and
    # required methods is [email phone cc], then prerequisite methods is
    # [email phone]
    prerequisite_methods = required_identity_verification_methods.take_while { |m| m != method }

    # Get the state of prerequisite methods. E.g. if <method> is cc and state is
    # { email: true, phone: false, cc: false }, then prerequisite methods state
    # is { email: true, phone: false }
    prerequisite_methods_state = identity_verification_state.select { |method| method.in? prerequisite_methods }

    # Check if all prerequisite methods are completed?
    prerequisite_methods_state.values.all?
  end

  def assumed_high_risk?
    custom_attributes.by_key(UserCustomAttribute::ASSUMED_HIGH_RISK_REASON).exists?
  end

  def assume_high_risk(reason:)
    UserCustomAttribute.set_assumed_high_risk_reason(user: self, reason: reason)
  end

  private

  def risk_band_based_methods
    methods = [email_method]

    case arkose_risk_band
    when Arkose::VerifyResponse::RISK_BAND_HIGH.downcase
      methods.append phone_number_method, credit_card_method
    when Arkose::VerifyResponse::RISK_BAND_MEDIUM.downcase
      methods.append phone_number_method
    when Arkose::VerifyResponse::RISK_BAND_LOW.downcase
      if phone_number_verification_enabled?
        experiment(:phone_verification_for_low_risk_users, user: self) do |e|
          e.candidate { methods.append VERIFICATION_METHODS[:PHONE_NUMBER] }
        end
      end
    end

    methods.compact
  end

  def credit_card_method
    return unless credit_card_verification_enabled?

    VERIFICATION_METHODS[:CREDIT_CARD]
  end

  def phone_number_method
    return unless phone_number_verification_enabled?

    VERIFICATION_METHODS[:PHONE_NUMBER]
  end

  def email_method
    VERIFICATION_METHODS[:EMAIL]
  end

  def identity_verification_exempt_methods
    [email_method]
  end

  def phone_number_exempt_methods
    [email_method, credit_card_method].compact
  end

  def arkose_high_risk?
    arkose_risk_band == Arkose::VerifyResponse::RISK_BAND_HIGH.downcase
  end

  def high_risk_or_assumed_high_risk?
    # Actual high risk users will be subject to the same order of required steps
    # as users assumed high risk when the daily phone verification transaction
    # limit is exceeded until it is reset
    daily_limit_exceeded = PhoneVerification::Users::SendVerificationCodeService.daily_transaction_limit_exceeded?
    high_risk = daily_limit_exceeded && arkose_high_risk?

    high_risk || assumed_high_risk?
  end

  def assumed_high_risk_user_methods
    [email_method, credit_card_method, phone_number_method].compact
  end

  def verification_method_required?(method:)
    return unless method.in? required_identity_verification_methods

    !identity_verification_state[method]
  end

  def verification_state
    @verification_state ||= {
      credit_card: -> { credit_card_verified? },
      phone: -> { phone_verified? },
      email: -> { email_verified? }
    }.stringify_keys
  end

  def phone_verified?
    phone_number_validation.present? && phone_number_validation.validated?
  end

  def email_verified?
    confirmed?
  end

  def credit_card_verification_enabled?
    return false unless is_a?(User)

    Feature.enabled?(:identity_verification_credit_card, self)
  end

  def phone_number_verification_enabled?
    return false unless is_a?(User)

    Feature.enabled?(:identity_verification_phone_number, self)
  end

  def phone_number_exemption_attribute
    custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT).first
  end
  strong_memoize_attr :phone_number_exemption_attribute

  def identity_verification_exemption_attribute
    custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT).first
  end
end
