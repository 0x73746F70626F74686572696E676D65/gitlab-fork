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

  IDENTITY_VERIFICATION_EXEMPT_METHODS = %w[email].freeze
  PHONE_NUMBER_EXEMPT_METHODS = %w[email credit_card].freeze
  ASSUMED_HIGH_RISK_USER_METHODS = %w[email credit_card phone].freeze
  HIGH_RISK_USER_METHODS = %w[email phone credit_card].freeze
  MEDIUM_RISK_USER_METHODS = %w[email phone].freeze
  LOW_RISK_USER_METHODS = %w[email].freeze

  def identity_verification_enabled?
    return false unless ::Gitlab::Saas.feature_available?(:identity_verification)
    return false unless ::Gitlab::CurrentSettings.email_confirmation_setting_hard?
    return false if ::Gitlab::CurrentSettings.require_admin_approval_after_user_signup

    true
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
    # 1. identity_verification_credit_card FF is disabled
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
    methods = determine_required_methods
    methods.select { |method| verification_method_enabled?(method) }
  end

  def credit_card_verified?
    credit_card_validation.present? && !credit_card_validation.used_by_banned_user?
  end

  def create_phone_number_exemption!
    return if phone_verified?
    return if exempt_from_phone_number_verification?

    custom_attributes.create!(
      key: UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT,
      value: true.to_s,
      user_id: id
    )
    clear_memoization(:phone_number_exemption_attribute)
    clear_memoization(:identity_verification_state)
  end

  def destroy_phone_number_exemption
    return unless phone_number_exemption_attribute

    phone_number_exemption_attribute.destroy
    clear_memoization(:phone_number_exemption_attribute)
    clear_memoization(:identity_verification_state)
  end

  def exempt_from_phone_number_verification?
    phone_number_exemption_attribute.present? &&
      ActiveModel::Type::Boolean.new.cast(phone_number_exemption_attribute.value)
  end

  def toggle_phone_number_verification
    exempt_from_phone_number_verification? ? destroy_phone_number_exemption : create_phone_number_exemption!
  end

  def create_identity_verification_exemption
    custom_attributes.create(key: UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT, value: true)
  end

  def destroy_identity_verification_exemption
    identity_verification_exemption_attribute&.destroy
  end

  def exempt_from_identity_verification?
    if Feature.enabled?(:exempt_paid_namespace_members_and_enterprise_users_from_identity_verification)
      return true if belongs_to_paid_namespace?(exclude_trials: true)
      return true if enterprise_user?
    end

    identity_verification_exemption_attribute.present?
  end

  def verification_method_enabled?(method)
    case method
    when 'phone'
      Feature.enabled?(:identity_verification_phone_number, self) &&
        !PhoneVerification::Users::RateLimitService.daily_transaction_hard_limit_exceeded?
    when 'credit_card'
      Feature.enabled?(:identity_verification_credit_card, self)
    else
      true
    end
  end

  def offer_phone_number_exemption?
    return false unless verification_method_enabled?('credit_card')
    return false unless verification_method_enabled?('phone')

    phone_required = verification_method_required?(method: VERIFICATION_METHODS[:PHONE_NUMBER])
    cc_required = verification_method_required?(method: VERIFICATION_METHODS[:CREDIT_CARD])

    return false if phone_required && cc_required

    # If phone verification is not required but a phone exemption exists it means the user toggled from
    # verifying with a phone to verifying with a credit card. Returning true if a phone exemption exists
    # will allow the user to toggle back to using phone verification from the credit card form.
    phone_required || exempt_from_phone_number_verification?
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

  delegate :arkose_verified?, :assume_low_risk!, :assume_high_risk!, :assumed_high_risk?, to: :risk_profile
  delegate :high_risk?, :medium_risk?, :low_risk?, to: :risk_profile, private: true

  private

  def risk_profile
    @risk_profile ||= IdentityVerification::UserRiskProfile.new(self)
  end

  def affected_by_phone_verifications_limit?
    # All users will be required to verify 1. email 2. credit card
    return true if PhoneVerification::Users::RateLimitService.daily_transaction_hard_limit_exceeded?

    # Actual high risk users will be subject to the same order of required steps
    # as users assumed high risk when the daily phone verification transaction
    # limit is exceeded until it is reset
    return high_risk? if PhoneVerification::Users::RateLimitService.daily_transaction_soft_limit_exceeded?

    false
  end

  def phone_number_verification_experiment_candidate?
    return unless low_risk? && verification_method_enabled?('phone')

    experiment(:phone_verification_for_low_risk_users, user: self) do |e|
      e.candidate { true }
    end.run
  end

  def determine_required_methods
    return IDENTITY_VERIFICATION_EXEMPT_METHODS if exempt_from_identity_verification?
    return PHONE_NUMBER_EXEMPT_METHODS if exempt_from_phone_number_verification?
    return ASSUMED_HIGH_RISK_USER_METHODS if assumed_high_risk? || affected_by_phone_verifications_limit?
    return HIGH_RISK_USER_METHODS if high_risk?
    return MEDIUM_RISK_USER_METHODS if medium_risk? || phone_number_verification_experiment_candidate?

    LOW_RISK_USER_METHODS
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

  def phone_number_exemption_attribute
    custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT).first
  end
  strong_memoize_attr :phone_number_exemption_attribute

  def identity_verification_exemption_attribute
    custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT).first
  end
end
