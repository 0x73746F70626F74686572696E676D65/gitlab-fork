# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::TermsAndConditionsController, :enable_admin_mode, feature_category: :custom_models do
  let(:admin) { create(:admin) }
  let(:duo_features_enabled) { true }

  before do
    sign_in(admin)
    stub_ee_application_setting(duo_features_enabled: duo_features_enabled)
  end

  shared_examples 'returns 404' do
    context 'when ai_custom_model feature flag is disabled' do
      before do
        stub_feature_flags(ai_custom_model: false)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user is not authorized' do
      it 'performs the right authorization correctly' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(admin, :manage_ai_settings).and_return(false)

        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #index' do
    subject :perform_request do
      get admin_ai_terms_and_conditions_url
    end

    it 'loads terms and conditions' do
      perform_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template('admin/ai/terms_and_conditions/index')
    end

    context 'when user has already accepted the terms' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
      end

      it 'redirects to self-hosted models index' do
        perform_request

        expect(response).to redirect_to(admin_ai_self_hosted_models_url)
      end
    end

    it_behaves_like 'returns 404'
  end

  describe 'POST #create' do
    subject :perform_request do
      post admin_ai_terms_and_conditions_url
    end

    it 'saves the acceptance' do
      expect { perform_request }.to change { ::Ai::TestingTermsAcceptance.count }.by(1)

      acceptance = ::Ai::TestingTermsAcceptance.last

      expect(acceptance.user_id).to eq(admin.id)
      expect(acceptance.user_email).to eq(admin.email)

      expect(response).to redirect_to(admin_ai_self_hosted_models_url)
    end

    it_behaves_like 'returns 404'
  end
end
