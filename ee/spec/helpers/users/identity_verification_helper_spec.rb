# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::IdentityVerificationHelper, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:user) { create(:user) }

  describe '#*identity_verification_data' do
    let(:signup_identity_verification_data) do
      {
        credit_card_challenge_on_verify: true,
        phone_challenge_on_verify: true,
        phone_show_arkose_challenge: false,
        phone_enable_arkose_challenge: false,
        phone_show_recaptcha_challenge: true,
        successful_verification_path: success_signup_identity_verification_path,
        verification_state_path: verification_state_signup_identity_verification_path,
        phone_exemption_path: toggle_phone_exemption_signup_identity_verification_path,
        phone_send_code_path: send_phone_verification_code_signup_identity_verification_path,
        phone_verify_code_path: verify_phone_verification_code_signup_identity_verification_path,
        credit_card_verify_path: verify_credit_card_signup_identity_verification_path,
        credit_card_verify_captcha_path: verify_credit_card_captcha_signup_identity_verification_path
      }
    end

    let(:identity_verification_data) do
      {
        credit_card_challenge_on_verify: false,
        phone_challenge_on_verify: false,
        phone_enable_arkose_challenge: true,
        phone_show_arkose_challenge: true,
        phone_show_recaptcha_challenge: false,
        successful_verification_path: success_identity_verification_path,
        verification_state_path: verification_state_identity_verification_path,
        phone_exemption_path: toggle_phone_exemption_identity_verification_path,
        phone_send_code_path: send_phone_verification_code_identity_verification_path,
        phone_verify_code_path: verify_phone_verification_code_identity_verification_path,
        credit_card_verify_path: verify_credit_card_identity_verification_path,
        arkose_data_exchange_payload: nil
      }
    end

    let(:common_data) do
      {
        offer_phone_number_exemption: mock_offer_phone_number_exemption,
        phone_challenge_on_send: true,
        phone_number: {},
        credit_card: {
          user_id: user.id,
          form_id: ::Gitlab::SubscriptionPortal::REGISTRATION_VALIDATION_FORM_ID
        },
        email: {
          obfuscated: helper.obfuscated_email(user.email),
          verify_path: verify_email_code_signup_identity_verification_path,
          resend_path: resend_email_code_signup_identity_verification_path
        },
        arkose: {
          api_key: 'api-key',
          domain: 'domain'
        }
      }
    end

    let(:signup_identity_verification_data_result) { common_data.merge(signup_identity_verification_data) }
    let(:identity_verification_data_result) { common_data.merge(identity_verification_data) }

    where(:method, :expected_data) do
      :signup_identity_verification_data | ref(:signup_identity_verification_data_result)
      :identity_verification_data        | ref(:identity_verification_data_result)
    end

    with_them do
      let(:mock_identity_verification_state) do
        { credit_card: false, email: true }
      end

      let(:mock_required_identity_verification_methods) { ['email'] }
      let(:mock_offer_phone_number_exemption) { true }

      before do
        allow(user).to receive(:required_identity_verification_methods).and_return(
          mock_required_identity_verification_methods
        )
        allow(user).to receive(:identity_verification_state).and_return(
          mock_identity_verification_state
        )
        allow(user).to receive(:offer_phone_number_exemption?).and_return(
          mock_offer_phone_number_exemption
        )

        allow(helper).to receive(:show_recaptcha_challenge?).and_return(true)

        allow(::Arkose::Settings).to receive(:arkose_public_api_key).and_return('api-key')
        allow(::Arkose::Settings).to receive(:arkose_labs_domain).and_return('domain')
        stub_feature_flags(arkose_labs_phone_verification_challenge: false)
      end

      subject(:data) { helper.send(method, user) }

      context 'when no phone number for user exists' do
        it 'returns the expected data' do
          expect(Gitlab::Json.parse(data[:data])).to eq(expected_data.deep_stringify_keys)
        end
      end

      context 'when phone number for user exists' do
        let_it_be(:record) { create(:phone_number_validation, user: user) }

        it 'returns the expected data' do
          phone_number_data = {
            country: record.country,
            international_dial_code: record.international_dial_code,
            number: record.phone_number,
            send_allowed_after: record.sms_send_allowed_after
          }

          json_result = Gitlab::Json.parse(data[:data])
          expect(json_result).to eq(expected_data.merge({ phone_number: phone_number_data }).deep_stringify_keys)
        end
      end
    end

    describe '#rate_limited_error_message' do
      subject(:message) { helper.rate_limited_error_message(limit) }

      let(:limit) { :credit_card_verification_check_for_reuse }

      it 'returns a generic error message' do
        expect(message).to eq(format(s_("IdentityVerification|You've reached the maximum amount of tries. " \
                                        'Wait %{interval} and try again.'), { interval: 'about 1 hour' }))
      end

      context 'when the limit is for email_verification_code_send' do
        let(:limit) { :email_verification_code_send }

        it 'returns a specific message' do
          expect(message).to eq(format(s_("IdentityVerification|You've reached the maximum amount of resends. " \
                                          'Wait %{interval} and try again.'), { interval: 'about 1 hour' }))
        end
      end
    end

    describe '#enable_arkose_challenge' do
      let(:category) { :phone }

      subject(:enable_arkose) { helper.enable_arkose_challenge?(category) }

      before do
        stub_feature_flags(arkose_labs_phone_verification_challenge: feature_flag_enabled)
        allow(helper).to receive(:show_recaptcha_challenge?).and_return(recaptcha_enabled)
      end

      context 'when arkose_labs_phone_verification_challenge feature-flag is disabled' do
        let(:feature_flag_enabled) { false }
        let(:recaptcha_enabled) { false }

        it { is_expected.to be_falsey }
      end

      context 'when arkose_labs_phone_verification_challenge feature-flag is enabled' do
        let(:feature_flag_enabled) { true }

        context 'and reCAPTCHA is disabled' do
          let(:recaptcha_enabled) { false }

          it { is_expected.to be_truthy }
        end

        context 'and reCAPTCHA is enabled' do
          let(:recaptcha_enabled) { true }

          it { is_expected.to be_falsey }
        end

        context 'and category is credit_card' do
          let(:category) { :credit_card }
          let(:recaptcha_enabled) { true }

          it { is_expected.to be_falsey }
        end
      end
    end

    describe '#show_arkose_challenge' do
      let(:category) { :phone }

      subject(:show_arkose) { helper.show_arkose_challenge?(user, category) }

      before do
        allow(helper).to receive(:enable_arkose_challenge?).and_return(arkose_enabled)

        allow(PhoneVerification::Users::RateLimitService)
          .to receive(:verification_attempts_limit_exceeded?)
          .with(user)
          .and_return(rate_limit_reached)
      end

      context 'when arkose is not enabled' do
        let(:arkose_enabled) { false }
        let(:rate_limit_reached) { false }

        it { is_expected.to be_falsey }
      end

      context 'when arkose is enabled' do
        let(:arkose_enabled) { true }

        context 'and when verification attempts have not been exceeded' do
          let(:rate_limit_reached) { false }

          it { is_expected.to be_falsey }
        end

        context 'and when verification attempts have been exceeded' do
          let(:rate_limit_reached) { true }

          it { is_expected.to be_truthy }
        end
      end
    end

    describe '#show_recaptcha_challenge' do
      subject(:show_recaptcha) { helper.show_recaptcha_challenge? }

      before do
        allow(Gitlab::Recaptcha).to receive(:enabled?).and_return(recaptcha_enabled)

        allow(PhoneVerification::Users::RateLimitService)
          .to receive(:daily_transaction_soft_limit_exceeded?).and_return(daily_limit_reached)
      end

      context 'when reCAPTCHA is not enabled' do
        let(:recaptcha_enabled) { false }
        let(:daily_limit_reached) { false }

        it { is_expected.to be_falsey }
      end

      context 'when reCAPTCHA is enabled' do
        let(:recaptcha_enabled) { true }

        context 'and daily limit is not reached' do
          let(:daily_limit_reached) { false }

          it { is_expected.to be_falsey }
        end

        context 'and daily limit is reached' do
          let(:daily_limit_reached) { true }

          it { is_expected.to be_truthy }
        end
      end
    end
  end

  describe '#identity_verification_data' do
    subject(:data) { helper.identity_verification_data(user) }

    let(:request_double) { instance_double(ActionDispatch::Request) }
    let(:data_exchange_payload) { 'data_exchange_payload' }

    before do
      allow(helper).to receive(:request).and_return(request_double)

      signup_options = { use_case: 'SIGN_UP', require_challenge: false }
      allow_next_instance_of(::Arkose::DataExchangePayload, request_double, signup_options) do |instance|
        allow(instance).to receive(:build).and_call_original
      end

      expected_options = { use_case: 'ACTIVE_USER', require_challenge: true }
      allow_next_instance_of(::Arkose::DataExchangePayload, request_double, expected_options) do |instance|
        allow(instance).to receive(:build).and_return(data_exchange_payload)
      end
    end

    it 'includes Arkose data exchange payload' do
      expect(Gitlab::Json.parse(data[:data])).to include(
        "arkose_data_exchange_payload" => data_exchange_payload
      )
    end
  end

  describe '#user_banned_error_message' do
    subject(:user_banned_error_message) { helper.user_banned_error_message }

    where(:dot_com, :error_message) do
      true  | "Your account has been blocked. Contact #{EE::CUSTOMER_SUPPORT_URL} for assistance."
      false | "Your account has been blocked. Contact your GitLab administrator for assistance."
    end

    with_them do
      before do
        allow(Gitlab).to receive(:com?).and_return(dot_com)
      end

      it 'returns the correct account banned error message' do
        expect(user_banned_error_message).to eq(error_message)
      end
    end
  end
end
