# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IdentityVerifiable, :saas, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }

  def add_user_risk_band(value)
    create(:user_custom_attribute, key: UserCustomAttribute::ARKOSE_RISK_BAND, value: value, user_id: user.id)
  end

  def add_phone_exemption
    create(:user_custom_attribute, key: UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT, value: true.to_s,
      user_id: user.id)
  end

  def add_identity_verification_exemption
    create(:user_custom_attribute, key: UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT, value: true, user: user)
  end

  def assume_high_risk(user)
    create(:user_custom_attribute, :assumed_high_risk_reason, user: user)
  end

  describe('#signup_identity_verification_enabled?') do
    where(
      identity_verification: [true, false],
      require_admin_approval_after_user_signup: [true, false],
      email_confirmation_setting: %w[soft hard off]
    )

    with_them do
      before do
        stub_saas_features(identity_verification: identity_verification)
        stub_application_setting(require_admin_approval_after_user_signup: require_admin_approval_after_user_signup)
        stub_application_setting_enum('email_confirmation_setting', email_confirmation_setting)
      end

      it 'returns the expected result' do
        result = identity_verification &&
          !require_admin_approval_after_user_signup &&
          email_confirmation_setting == 'hard'

        expect(user.signup_identity_verification_enabled?).to eq(result)
      end
    end
  end

  describe('#identity_verification_enabled?') do
    let_it_be(:user) { build_stubbed(:user) }

    subject { user.identity_verification_enabled? }

    context 'when verification methods are available' do
      where(:feature_available, :feature_flag_enabled, :result) do
        false | false | false
        true  | false | false
        false | true  | false
        true  | true  | true
      end

      with_them do
        before do
          stub_saas_features(identity_verification: feature_available)
          stub_feature_flags(opt_in_identity_verification: feature_flag_enabled)
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when verification methods are unavailable' do
      before do
        stub_feature_flags(
          identity_verification_phone_number: false,
          identity_verification_credit_card: false
        )
      end

      context 'when the user is not active' do
        it 'is enabled for email verification', :aggregate_failures do
          expect(subject).to eq(true)
          expect(user.required_identity_verification_methods).to eq(['email'])
        end
      end

      context 'when the user is active' do
        let_it_be(:user) { build_stubbed(:user, :with_sign_ins) }

        it { is_expected.to eq(false) }
      end
    end
  end

  describe('#identity_verified?') do
    let_it_be(:user) { create(:user, :identity_verification_eligible) }

    subject(:identity_verified?) { user.identity_verified? }

    where(:phone_verified, :credit_card_verified, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(user).to receive(:identity_verification_enabled?).and_return(true)
        allow(user).to receive(:identity_verification_state).and_return(
          {
            phone: phone_verified,
            credit_card: credit_card_verified
          }
        )
      end

      it { is_expected.to eq(result) }
    end

    context 'when identity verification is not enabled' do
      before do
        allow(user).to receive(:identity_verification_enabled?).and_return(false)
      end

      it { is_expected.to eq(true) }
    end

    context 'when the user is exempt from identity verification' do
      before do
        allow(user).to receive(:identity_verification_exempt?).and_return(true)
      end

      it { is_expected.to eq true }
    end

    context 'when the user has a pre-existing credit card validation' do
      before do
        allow(user).to receive(:identity_verification_enabled?).and_return(true)
        allow(user).to receive(:credit_card_verified?).and_return(credit_card_verified)
        allow(user).to receive(:identity_verification_state) do
          state = { described_class::VERIFICATION_METHODS[:PHONE_NUMBER] => phone_verified }
          state[described_class::VERIFICATION_METHODS[:CREDIT_CARD]] = credit_card_verified if credit_card_required

          state
        end
      end

      where(:credit_card_required, :credit_card_verified, :phone_verified, :result) do
        true  | true  | true  | true
        true  | true  | false | false
        true  | false | true  | false
        true  | false | false | false
        false | true  | true  | true
        false | true  | false | true
        false | false | true  | true
        false | false | false | false
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end

    context 'when the user is a bot' do
      let_it_be(:user) { create(:user, :project_bot) }
      let_it_be(:human_user) { build_stubbed(:user, :with_sign_ins, :identity_verification_eligible) }

      before do
        allow(user).to receive(:created_by).and_return(human_user)
      end

      it 'verifies the identity of the bot creator', :aggregate_failures do
        expect(human_user).to receive(:identity_verified?).and_call_original

        expect(identity_verified?).to eq(false)
      end

      context 'when the user is not a project bot' do
        let(:user) { build_stubbed(:user, :admin_bot) }

        it { is_expected.to eq(true) }
      end

      context 'when the bot is in a paid namespace' do
        before do
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
        end

        it { is_expected.to eq(true) }
      end

      context 'when the bot is in a trial namespace' do
        before do
          create(:group_with_plan, plan: :ultimate_trial_plan, developers: user)
        end

        it { is_expected.to eq(false) }
      end

      context 'when the bot creator is nil' do
        before do
          allow(user).to receive(:created_by).and_return(nil)
        end

        context 'when the bot was created after the feature release date' do
          let(:created_after_release_day) { true }

          it 'does not verify the user', :aggregate_failures do
            expect(user).to receive(:created_after_require_identity_verification_release_day?).and_return(true)
            expect(identity_verified?).to eq(false)
          end
        end

        context 'when the bot was created before the feature release date' do
          let(:created_after_release_day) { false }

          it 'verifies the user' do
            expect(user).to receive(:created_after_require_identity_verification_release_day?).and_return(false)
            expect(identity_verified?).to eq(true)
          end
        end
      end

      context 'when the bot creator has been banned' do
        it 'does not verify the user', :aggregate_failures do
          expect(human_user).to receive(:banned?).and_return(true)
          expect(human_user).not_to receive(:identity_verified?)

          expect(identity_verified?).to eq(false)
        end
      end
    end

    describe 'created_at relative to release date' do
      where(:require_for_old_users?, :old_user?, :result) do
        false | false | false
        false | true  | true
        true  | false | false
        true  | true  | false
      end

      with_them do
        before do
          allow(user).to receive(:identity_verification_enabled?).and_return(true)
          allow(user).to receive(:identity_verification_state).and_return({ phone: false })

          stub_feature_flags(require_identity_verification_for_old_users: require_for_old_users?)

          created_at =
            if old_user?
              described_class::IDENTITY_VERIFICATION_RELEASE_DATE - 1.day
            else
              described_class::IDENTITY_VERIFICATION_RELEASE_DATE + 1.day
            end

          allow(user).to receive(:created_at).and_return(created_at)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe('#active_for_authentication?') do
    subject { user.active_for_authentication? }

    where(:identity_verification_enabled?, :identity_verified?, :email_confirmation_setting, :result) do
      true  | true  | 'hard' | true
      true  | false | 'hard' | false
      false | false | 'hard' | true
      false | true  | 'hard' | true
      true  | true  | 'soft' | true
      true  | false | 'soft' | false
      false | false | 'soft' | true
      false | true  | 'soft' | true
    end

    before do
      allow(user).to receive(:signup_identity_verification_enabled?).and_return(identity_verification_enabled?)
      allow(user).to receive(:signup_identity_verified?).and_return(identity_verified?)
      stub_application_setting_enum('email_confirmation_setting', email_confirmation_setting)
    end

    with_them do
      context 'when not confirmed' do
        before do
          allow(user).to receive(:confirmed?).and_return(false)
        end

        it { is_expected.to eq(false) }
      end

      context 'when confirmed' do
        before do
          allow(user).to receive(:confirmed?).and_return(true)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe('#signup_identity_verified?') do
    subject { user.signup_identity_verified? }

    where(:phone_verified, :email_verified, :result) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(user).to receive(:signup_identity_verification_enabled?).and_return(true)
        allow(user).to receive(:identity_verification_state).and_return(
          {
            phone: phone_verified,
            email: email_verified
          }
        )
      end

      it { is_expected.to eq(result) }
    end

    context 'when identity verification is not enabled' do
      before do
        allow(user).to receive(:signup_identity_verification_enabled?).and_return(false)
      end

      context 'and their email is already verified' do
        it { is_expected.to eq(true) }
      end

      context 'and their email is not yet verified' do
        let(:user) { create(:user, :unconfirmed) }

        it { is_expected.to eq(false) }
      end
    end

    context 'when user has already signed in before' do
      context 'and their email is already verified' do
        let(:user) { create(:user, last_sign_in_at: Time.zone.now) }

        it { is_expected.to eq(true) }
      end

      context 'and their email is not yet verified' do
        let(:user) { create(:user, :unconfirmed, last_sign_in_at: Time.zone.now) }

        it { is_expected.to eq(false) }
      end
    end
  end

  describe('#required_identity_verification_methods') do
    subject { user.required_identity_verification_methods }

    let(:user) { create(:user) }

    where(:risk_band, :credit_card, :phone_number, :phone_exempt, :identity_verification_exempt, :result) do
      'High'   | true  | true  | false | false | %w[email phone credit_card]
      'High'   | true  | true  | true  | false | %w[email credit_card]
      'High'   | true  | true  | false | true  | %w[email]
      'High'   | false | true  | false | false | %w[email phone]
      'High'   | true  | false | false | false | %w[email credit_card]
      'High'   | false | false | false | false | %w[email]
      'Medium' | true  | true  | false | false | %w[email phone]
      'Medium' | false | true  | false | false | %w[email phone]
      'Medium' | true  | true  | true  | false | %w[email credit_card]
      'Medium' | true  | true  | false | true  | %w[email]
      'Medium' | true  | false | false | false | %w[email]
      'Medium' | false | false | false | false | %w[email]
      'Low'    | true  | true  | false | false | %w[email]
      'Low'    | false | true  | false | false | %w[email]
      'Low'    | true  | false | false | false | %w[email]
      'Low'    | false | false | false | false | %w[email]
      nil      | true  | true  | false | false | %w[email]
      nil      | false | true  | false | false | %w[email]
      nil      | true  | false | false | false | %w[email]
      nil      | false | false | false | false | %w[email]
    end

    with_them do
      before do
        add_user_risk_band(risk_band) if risk_band
        add_phone_exemption if phone_exempt
        add_identity_verification_exemption if identity_verification_exempt

        stub_feature_flags(identity_verification_credit_card: credit_card)
        stub_feature_flags(identity_verification_phone_number: phone_number)
      end

      it { is_expected.to eq(result) }
    end

    context 'when user is already active i.e. signed in at least once' do
      let(:user) { create(:user, :unconfirmed, last_sign_in_at: Time.zone.now) }

      where(:phone_exempt, :email_verified, :assumed_high_risk, :affected_by_phone_verifications_limit, :result) do
        false | true  | false | false | %w[phone]
        false | false | false | false | %w[email]
        true  | true  | false | false | %w[credit_card]
        false | true  | true  | false | %w[credit_card phone]
        false | false | true  | false | %w[email credit_card phone]
        false | true  | false | true  | %w[credit_card]
      end

      with_them do
        before do
          add_phone_exemption if phone_exempt
          assume_high_risk(user) if assumed_high_risk
          user.confirm if email_verified

          # Disables phone number verification method
          allow(PhoneVerification::Users::RateLimitService)
            .to receive(:daily_transaction_hard_limit_exceeded?).and_return(affected_by_phone_verifications_limit)
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when flag is enabled for a specific user' do
      let_it_be(:another_user) { create(:user) }

      where(:risk_band, :credit_card, :phone_number, :result) do
        'High'   | true  | false | %w[email credit_card]
        'Medium' | false | true  | %w[email phone]
      end

      with_them do
        before do
          stub_feature_flags(
            identity_verification_phone_number: false,
            identity_verification_credit_card: false
          )

          add_user_risk_band(risk_band)
          create(:user_custom_attribute, key: UserCustomAttribute::ARKOSE_RISK_BAND, value: risk_band,
            user: another_user)

          stub_feature_flags(identity_verification_phone_number: user) if phone_number
          stub_feature_flags(identity_verification_credit_card: user) if credit_card
        end

        it 'only affects that user' do
          expect(user.required_identity_verification_methods).to eq(result)
          expect(another_user.required_identity_verification_methods).to eq(%w[email])
        end
      end
    end

    describe 'phone_verification_for_low_risk_users experiment', :experiment do
      let(:user) { create(:user) }
      let(:experiment_instance) { experiment(:phone_verification_for_low_risk_users) }

      before do
        add_user_risk_band('Low')
      end

      subject(:verification_methods) { user.required_identity_verification_methods }

      context 'when the user is in the control group' do
        before do
          stub_experiments(phone_verification_for_low_risk_users: :control)
        end

        it { is_expected.to eq(%w[email]) }

        it 'tracks control group assignment for the user' do
          expect(experiment_instance).to track(:assignment).on_next_instance.with_context(user: user).for(:control)

          verification_methods
        end
      end

      context 'when the user is in the candidate group' do
        before do
          stub_experiments(phone_verification_for_low_risk_users: :candidate)
        end

        it { is_expected.to eq(%w[email phone]) }

        it 'tracks candidate group assignment for the user' do
          expect(experiment_instance).to track(:assignment).on_next_instance.with_context(user: user).for(:candidate)

          verification_methods
        end
      end

      context 'when the experiment is disabled' do
        before do
          stub_experiments(phone_verification_for_low_risk_users: false)
        end

        it { is_expected.to eq(%w[email]) }

        it 'does not track assignment' do
          expect(experiment_instance).not_to track(:assignment).on_next_instance

          verification_methods
        end
      end

      context 'when phone verification is disabled' do
        before do
          stub_experiments(phone_verification_for_low_risk_users: :candidate)
          stub_feature_flags(identity_verification_phone_number: false)
        end

        it { is_expected.to eq(%w[email]) }

        it 'does not track assignment' do
          expect(experiment_instance).not_to track(:assignment).on_next_instance

          verification_methods
        end
      end
    end

    context 'when phone verifications soft limit has been exceeded' do
      where(:risk_band, :result) do
        'High'   | %w[email credit_card phone]
        'Medium' | %w[email phone]
        'Low'    | %w[email]
        nil      | %w[email]
      end

      with_them do
        before do
          allow(PhoneVerification::Users::RateLimitService)
            .to receive(:daily_transaction_soft_limit_exceeded?).and_return(true)
          allow(PhoneVerification::Users::RateLimitService)
            .to receive(:daily_transaction_hard_limit_exceeded?).and_return(false)
          add_user_risk_band(risk_band) if risk_band
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when phone verifications hard limit has been exceeded' do
      before do
        allow(PhoneVerification::Users::RateLimitService)
          .to receive(:daily_transaction_soft_limit_exceeded?).and_return(true)
        allow(PhoneVerification::Users::RateLimitService)
          .to receive(:daily_transaction_hard_limit_exceeded?).and_return(true)

        add_user_risk_band(risk_band) if risk_band
      end

      where(:risk_band, :result) do
        'High'   | %w[email credit_card]
        'Medium' | %w[email credit_card]
        'Low'    | %w[email credit_card]
        nil      | %w[email credit_card]
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end

    context 'when user is assumed high risk' do
      where(:risk_band, :phone_exempt, :identity_verification_exempt, :result) do
        'High'   | false | false | %w[email credit_card phone]
        'High'   | true  | false | %w[email credit_card]
        'High'   | false | true  | %w[email]
        'Medium' | false | false | %w[email credit_card phone]
        'Medium' | true  | false | %w[email credit_card]
        'Medium' | false | true  | %w[email]
        'Low'    | false | false | %w[email credit_card phone]
        'Low'    | true  | false | %w[email credit_card]
        'Low'    | false | true  | %w[email]
        nil      | false | false | %w[email credit_card phone]
        nil      | true  | false | %w[email credit_card]
        nil      | false | true  | %w[email]
      end

      with_them do
        before do
          assume_high_risk(user)

          add_user_risk_band(risk_band) if risk_band
          add_phone_exemption if phone_exempt
          add_identity_verification_exemption if identity_verification_exempt
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe('#identity_verification_state') do
    describe 'credit card verification state' do
      before do
        add_user_risk_band('High')
      end

      subject { user.identity_verification_state['credit_card'] }

      context 'when user has not verified a credit card' do
        let(:user) { create(:user, credit_card_validation: nil) }

        it { is_expected.to eq false }
      end

      context 'when user has verified a credit card' do
        let(:validation) { create(:credit_card_validation) }
        let(:user) { create(:user, credit_card_validation: validation) }

        it { is_expected.to eq true }
      end
    end

    describe 'phone verification state' do
      before do
        add_user_risk_band('Medium')
      end

      subject { user.identity_verification_state['phone'] }

      context 'when user has no phone number' do
        let(:user) { create(:user, phone_number_validation: nil) }

        it { is_expected.to eq false }
      end

      context 'when user has not verified a phone number' do
        let(:validation) { create(:phone_number_validation) }
        let(:user) { create(:user, phone_number_validation: validation) }

        before do
          allow(validation).to receive(:validated?).and_return(false)
        end

        it { is_expected.to eq false }
      end

      context 'when user has verified a phone number' do
        let(:validation) { create(:phone_number_validation) }
        let(:user) { create(:user, phone_number_validation: validation) }

        before do
          allow(validation).to receive(:validated?).and_return(true)
        end

        it { is_expected.to eq true }
      end
    end

    describe 'email verification state' do
      subject { user.identity_verification_state['email'] }

      context 'when user has not verified their email' do
        let(:user) { create(:user, :unconfirmed) }

        it { is_expected.to eq false }
      end

      context 'when user has verified their email' do
        let(:user) { create(:user) }

        it { is_expected.to eq true }
      end
    end
  end

  describe('#credit_card_verified?') do
    subject { user.credit_card_verified? }

    context 'when user has not verified a credit card' do
      it { is_expected.to eq false }
    end

    context 'when user has verified a credit card' do
      let!(:credit_card_validation) { create(:credit_card_validation, user: user) }

      it { is_expected.to eq true }

      context 'when credit card has been used by a banned user' do
        before do
          allow(credit_card_validation).to receive(:used_by_banned_user?).and_return(true)
        end

        it { is_expected.to eq false }
      end
    end
  end

  describe '#exempt_from_phone_number_verification?' do
    subject(:phone_number_exemption_attribute) { user.exempt_from_phone_number_verification? }

    let(:user) { create(:user) }

    context 'when a user has a phone number exemption' do
      before do
        add_phone_exemption
      end

      it { is_expected.to be true }
    end

    context 'when a user does not have an exemption' do
      it { is_expected.to be false }
    end
  end

  describe '#create_phone_number_exemption!' do
    subject(:create_phone_number_exemption) { user.create_phone_number_exemption! }

    let(:user) { create(:user) }

    it 'creates an exemption', :aggregate_failures do
      expect(user).to receive(:clear_memoization).with(:phone_number_exemption_attribute).and_call_original
      expect(user).to receive(:clear_memoization).with(:identity_verification_state).and_call_original

      expect { subject }.to change {
        user.custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT).count
      }.from(0).to(1)
    end

    shared_examples 'it does not create an exemption' do
      it 'does not create an exemption', :aggregate_failures do
        expect(user).not_to receive(:clear_memoization)

        expect { subject }.not_to change {
          user.custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT).count
        }
      end
    end

    context 'when user has already verified a phone number' do
      before do
        create(:phone_number_validation, :validated, user: user)
      end

      it_behaves_like 'it does not create an exemption'
    end

    context 'when user is already exempt' do
      before do
        add_phone_exemption
      end

      it_behaves_like 'it does not create an exemption'
    end
  end

  describe '#destroy_phone_number_exemption' do
    subject(:destroy_phone_number_exemption) { user.destroy_phone_number_exemption }

    let(:user) { create(:user) }

    context 'when a user has a phone number exemption' do
      it 'destroys the exemption', :aggregate_failures do
        add_phone_exemption

        expect(user).to receive(:clear_memoization).with(:phone_number_exemption_attribute).and_call_original
        expect(user).to receive(:clear_memoization).with(:identity_verification_state).and_call_original

        subject

        expect(user.custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_PHONE_EXEMPT)).to be_empty
      end
    end

    context 'when a user does not have a phone number exemption' do
      it { is_expected.to be_nil }
    end
  end

  describe '#identity_verification_exempt?' do
    subject(:identity_verification_exempt) { user.identity_verification_exempt? }

    let(:user) { create(:user) }

    let_it_be(:group_paid) { create(:group_with_plan, :public, plan: :ultimate_plan) }

    let_it_be(:group_trial) do
      create(:group_with_plan, :public, plan: :ultimate_plan, trial_ends_on: Time.current + 30.days)
    end

    context 'when a user has a identity verification exemption by custom attribute' do
      before do
        add_identity_verification_exemption
      end

      it { is_expected.to be true }
    end

    context 'when a user is an enterprise user' do
      let(:user) { create(:enterprise_user) }

      it { is_expected.to be true }
    end

    context 'when a user is a pending member of a paid non-trial namespace' do
      before do
        create(:group_member, :awaiting, :developer, source: group_paid, user: user)
      end

      it { is_expected.to be true }
    end

    context 'when a user is a member of a paid non-trial namespace' do
      before do
        create(:group_member, :developer, source: group_paid, user: user)
      end

      it { is_expected.to be true }
    end

    context 'when a user is a member of a paid trial namespace' do
      before do
        create(:group_member, :awaiting, :developer, source: group_trial, user: user)
      end

      it { is_expected.to be_falsy }
    end

    context 'when a user is not an enterprise user, a paid namespace member or exempted by custom attribute' do
      it { is_expected.to be_falsy }
    end
  end

  describe '#create_identity_verification_exemption' do
    subject(:create_identity_verification_exemption) { user.create_identity_verification_exemption('because') }

    let(:user) { create(:user) }

    it 'creates an exemption', :aggregate_failures do
      expect { subject }.to change {
        user.custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT).count
      }.from(0).to(1)

      expect(
        user.custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT).first.value
      ).to eq('because')
    end
  end

  describe '#destroy_identity_verification_exemption' do
    subject(:destroy_identity_verification_exemption) { user.destroy_identity_verification_exemption }

    let(:user) { create(:user) }

    context 'when a user has a identity verification exemption' do
      before do
        add_identity_verification_exemption
      end

      it 'destroys the exemption' do
        subject

        expect(user.custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT)).to be_empty
      end
    end

    context 'when a user does not have a identity verification exemption' do
      it { is_expected.to be_falsy }
    end
  end

  describe '#toggle_phone_number_verification' do
    before do
      allow(user).to receive(:clear_memoization).with(:phone_number_exemption_attribute).and_call_original
      allow(user).to receive(:clear_memoization).with(:identity_verification_state).and_call_original
    end

    subject(:toggle_phone_number_verification) { user.toggle_phone_number_verification }

    context 'when not exempt from phone number verification' do
      it 'creates an exemption' do
        expect(user).to receive(:create_phone_number_exemption!)

        toggle_phone_number_verification
      end
    end

    context 'when exempt from phone number verification' do
      it 'destroys the exemption' do
        user.create_phone_number_exemption!

        expect(user).to receive(:destroy_phone_number_exemption)

        toggle_phone_number_verification
      end
    end

    it 'clears memoization of identity_verification_state' do
      expect(user).to receive(:clear_memoization).with(:identity_verification_state)

      toggle_phone_number_verification
    end
  end

  describe '#offer_phone_number_exemption?' do
    subject(:offer_phone_number_exemption?) { user.offer_phone_number_exemption? }

    where(:credit_card, :phone_number, :phone_exempt, :required_verification_methods, :result) do
      true   | true  | false | %w[email]                   | false
      false  | true  | false | %w[email phone]             | false
      true   | true  | false | %w[email phone]             | true
      true   | false | false | %w[email credit_card]       | false
      true   | true  | false | %w[email credit_card]       | false
      true   | true  | true  | %w[email credit_card]       | true
      true   | true  | false | %w[email phone credit_card] | false
    end

    with_them do
      before do
        stub_feature_flags(identity_verification_credit_card: credit_card)
        stub_feature_flags(identity_verification_phone_number: phone_number)

        allow(user).to receive(:required_identity_verification_methods).and_return(required_verification_methods)
        allow(user).to receive(:exempt_from_phone_number_verification?).and_return(phone_exempt)
      end

      it { is_expected.to eq(result) }
    end
  end

  describe '#verification_method_allowed?' do
    subject(:result) { user.verification_method_allowed?(method: method) }

    context 'when verification method is not required' do
      let_it_be(:user) { create(:user, :medium_risk, confirmed_at: Time.current) }
      let(:method) { 'credit_card' }

      it { is_expected.to eq false }
    end

    context 'when verification method is required but already completed' do
      let_it_be(:user) { create(:user, :low_risk, confirmed_at: Time.current) }
      let(:method) { 'email' }

      it { is_expected.to eq false }
    end

    context 'when verification method is required and not completed' do
      context 'when there are prerequisite verification methods' do
        let(:method) { 'credit_card' }

        context 'when all prerequisite verification methods are completed' do
          let_it_be(:user) { create(:user, :high_risk, confirmed_at: Time.current) }
          let_it_be(:phone_number_validation) { create(:phone_number_validation, :validated, user: user) }

          it { is_expected.to eq true }
        end

        context 'when any of prerequisite verification methods are incomplete' do
          let_it_be(:user) { create(:user, :high_risk, confirmed_at: Time.current) }

          it { is_expected.to eq false }
        end

        context 'when all of prerequisite verification methods are incomplete' do
          let_it_be(:user) { create(:user, :high_risk, :unconfirmed) }

          it { is_expected.to eq false }
        end
      end

      context 'when there are no prerequisite verification methods' do
        let_it_be(:user) { create(:user, :unconfirmed) }
        let(:method) { 'email' }

        it { is_expected.to eq true }
      end
    end
  end

  describe '#requires_identity_verification_to_create_group?' do
    let_it_be(:top_level_group) { build(:group) }
    let(:group) { top_level_group }

    subject { user.requires_identity_verification_to_create_group?(group) }

    before do
      allow(user).to receive(:identity_verification_enabled?).and_return(true)
      allow(user).to receive(:identity_verified?).and_return(false)
    end

    context 'when the user has created the max number of groups' do
      before do
        create_list(:group, IdentityVerifiable::UNVERIFIED_USER_CREATED_GROUP_LIMIT, creator: user)
      end

      it { is_expected.to eq(true) }

      context 'when the group is a subgroup' do
        let(:group) { build(:group, parent: top_level_group) }

        it { is_expected.to eq(false) }
      end

      context 'when the feature is disabled' do
        before do
          stub_feature_flags(unverified_account_group_creation_limit: false)
        end

        it { is_expected.to eq(false) }
      end

      context 'when the user is already identity verified' do
        before do
          allow(user).to receive(:identity_verified?).and_return(true)
        end

        it { is_expected.to eq(false) }
      end
    end

    context 'when the user has not created the max number of groups' do
      before do
        create_list(:group, IdentityVerifiable::UNVERIFIED_USER_CREATED_GROUP_LIMIT - 1, creator: user)
      end

      it { is_expected.to eq(false) }
    end
  end

  it 'delegates risk profile methods', :aggregate_failures do
    expect_next_instance_of(IdentityVerification::UserRiskProfile, user) do |instance|
      expect(instance).to receive(:arkose_verified?).ordered
      expect(instance).to receive(:assume_low_risk!).with(reason: 'Low reason').ordered
      expect(instance).to receive(:assume_high_risk!).with(reason: 'High reason').ordered
      expect(instance).to receive(:assumed_high_risk?).ordered
    end

    user.arkose_verified?
    user.assume_low_risk!(reason: 'Low reason')
    user.assume_high_risk!(reason: 'High reason')
    user.assumed_high_risk?
  end
end
