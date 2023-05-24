# frozen_string_literal: true

# goal of this context: provide a close/stable representation of how SaaS is configured currently
# things that belong in here:
# - settled-not-yet-removed-in-saas feature flag settings
# - application settings for SaaS
# - .com specific type things like enforcing of terms
# things that don't belong in here:
# - unsettled feature flag settings in SaaS(still in rollout), instead test both branches to cover SaaS
RSpec.shared_context 'with saas settings for registration flows', shared_context: :metadata do # rubocop: disable RSpec/SharedGroupsMetadata
  include TermsHelper
  include SaasRegistrationHelpers

  before do
    # Saas doesn't require admin approval.
    stub_application_setting(require_admin_approval_after_user_signup: false)

    stub_application_setting(check_namespace_plan: true)
    stub_application_setting(import_sources: %w[github gitlab_project])

    # SaaS always requires confirmation, since the default is set to `off` we want to ensure SaaS is set to `hard`
    stub_application_setting_enum('email_confirmation_setting', 'hard')

    stub_feature_flags(
      # our focus isn't around arkose/signup challenges, so we'll omit those
      arkose_labs_signup_challenge: false,
      # currently being rolled out, not yet on in prod
      identity_verification: false,
      ensure_onboarding: true
    )

    enforce_terms
  end
end

RSpec.shared_context 'with saas sso settings for registration flows', shared_context: :metadata do # rubocop: disable RSpec/SharedGroupsMetadata
  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_feature_flags(
      arkose_labs_oauth_signup_challenge: true,
      identity_verification: true
    )
  end

  around do |example|
    with_omniauth_full_host { example.run }
  end
end

RSpec.shared_context 'with saas settings for subscription registration flows', shared_context: :metadata do # rubocop: disable RSpec/SharedGroupsMetadata
  include SubscriptionPortalHelpers

  before do
    stub_signing_key
  end
end

RSpec.configure do |rspec|
  rspec.include_context 'with saas settings for registration flows', saas_registration: true
  rspec.include_context 'with saas settings for registration flows', saas_sso_registration: true
  rspec.include_context 'with saas sso settings for registration flows', saas_sso_registration: true
  rspec.include_context 'with saas settings for registration flows', saas_subscription_registration: true
  rspec.include_context 'with saas settings for subscription registration flows', saas_subscription_registration: true
end
