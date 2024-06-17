# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::IdentityVerificationController, :clean_gitlab_redis_sessions,
  :clean_gitlab_redis_rate_limiting, feature_category: :instance_resiliency do
  include SessionHelpers

  let_it_be(:user) { create(:user, :low_risk) }

  before do
    allow(user).to receive(:verification_method_allowed?).and_return(true)
    allow(user).to receive(:identity_verified?).and_return(false)

    stub_saas_features(identity_verification: true)

    login_as(user)
  end

  shared_examples 'it redirects to root_path when user is already verified' do
    let_it_be_with_reload(:user) { create(:user) }

    subject do
      do_request

      response
    end

    before do
      allow(user).to receive(:identity_verified?).and_call_original

      create(:phone_number_validation, :validated, user: user)
    end

    it { is_expected.to redirect_to(root_path) }

    context 'when identity_verification saas feature is not available' do
      before do
        stub_saas_features(identity_verification: false)
      end

      it { is_expected.to redirect_to(root_path) }
    end

    context 'when opt_in_identity_verification feature flag is disabled' do
      before do
        stub_feature_flags(opt_in_identity_verification: false)
      end

      it { is_expected.to redirect_to(root_path) }
    end
  end

  describe 'GET show' do
    subject(:do_request) { get identity_verification_path, params: {}, headers: { referer: '/referer/path' } }

    it_behaves_like 'it requires a signed in user'
    it_behaves_like 'it redirects to root_path when user is already verified'

    it 'renders show template with minimal layout' do
      do_request

      expect(response).to render_template('show', layout: 'minimal')
    end

    it 'sets session[:identity_verification_referer]' do
      do_request

      expect(session[:identity_verification_referer]).to eq '/referer/path'
    end
  end

  describe 'GET verification_state' do
    subject(:do_request) { get verification_state_identity_verification_path }

    it_behaves_like 'it requires a signed in user'
    it_behaves_like 'it redirects to root_path when user is already verified'
    it_behaves_like 'it sets poll interval header'

    it 'returns verification methods and state' do
      do_request

      expect(json_response).to eq({
        'verification_methods' => ["phone"],
        'verification_state' => { "phone" => false },
        'methods_requiring_arkose_challenge' => ["phone"]
      })
    end
  end

  describe 'POST send_phone_verification_code' do
    let_it_be(:params) do
      {
        arkose_labs_token: 'verification-token',
        identity_verification: { country: 'US', international_dial_code: '1', phone_number: '555' }
      }
    end

    subject(:do_request) { post send_phone_verification_code_identity_verification_path(params) }

    before do
      mock_arkose_token_verification(success: true)
    end

    describe 'before action hooks' do
      before do
        mock_send_phone_number_verification_code(success: true)
      end

      it_behaves_like 'it redirects to root_path when user is already verified'
      it_behaves_like 'it verifies arkose token', 'phone' do
        let(:target_user) { user }
      end

      it_behaves_like 'it ensures verification attempt is allowed', 'phone' do
        let(:target_user) { user }
      end
    end

    it_behaves_like 'it successfully sends phone number verification code'
    it_behaves_like 'it handles failed phone number verification code send'
  end

  describe 'POST verify_phone_verification_code' do
    let_it_be(:params) do
      { identity_verification: { verification_code: '999' } }
    end

    subject(:do_request) { post verify_phone_verification_code_identity_verification_path(params) }

    describe 'before action hooks' do
      before do
        mock_verify_phone_number_verification_code(success: true)
      end

      it_behaves_like 'it ensures verification attempt is allowed', 'phone' do
        let(:target_user) { user }
      end

      it_behaves_like 'it redirects to root_path when user is already verified'
    end

    it_behaves_like 'it successfully verifies a phone number verification code'
    it_behaves_like 'it handles failed phone number code verification'
  end

  describe 'POST verify_credit_card_captcha' do
    subject(:do_request) { post verify_credit_card_captcha_identity_verification_path }

    it_behaves_like 'it ensures verification attempt is allowed', 'credit_card' do
      let_it_be(:cc) { create(:credit_card_validation, user: user) }
      let(:target_user) { user }
    end

    it_behaves_like 'it verifies arkose token', 'credit_card' do
      let(:target_user) { user }
    end
  end

  describe 'GET verify_credit_card' do
    let_it_be_with_reload(:user) { create(:user, :low_risk) }

    let(:params) { { format: :json } }

    subject(:do_request) { get verify_credit_card_identity_verification_path(params) }

    it_behaves_like 'it redirects to root_path when user is already verified'
    it_behaves_like 'it verifies presence of credit_card_validation record for the user'
  end

  describe 'PATCH toggle_phone_exemption' do
    let(:user) { create(:user, :low_risk) }

    subject(:do_request) { patch toggle_phone_exemption_identity_verification_path(format: :json) }

    it_behaves_like 'it redirects to root_path when user is already verified'
    it_behaves_like 'toggles phone number verification exemption for the user' do
      let(:target_user) { user }
    end
  end

  describe 'GET success' do
    subject(:do_request) { get success_identity_verification_path }

    context 'when session[:identity_verification_referer] is set' do
      before do
        stub_session(session_data: { identity_verification_referer: '/expected/redirect/path' })
      end

      it 'redirects to the path set in session[:identity_verification_referer]' do
        do_request

        expect(response).to redirect_to('/expected/redirect/path')
      end
    end

    context 'when session[:identity_verification_referer] is not set' do
      it 'redirects to the path set in session[:identity_verification_referer]' do
        do_request

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
