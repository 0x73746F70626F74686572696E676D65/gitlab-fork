# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::SelfHostedModelsController, :enable_admin_mode, feature_category: :custom_models do
  let(:admin) { create(:admin) }
  let(:duo_features_enabled) { true }

  before do
    sign_in(admin)
    stub_ee_application_setting(duo_features_enabled: duo_features_enabled)
    stub_feature_flags(custom_models_vue_app: false) # disables vue app while running test suite

    allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
  end

  shared_examples 'must accept terms and conditions' do
    context 'when terms have not been accepted' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
      end

      it 'redirects to terms page' do
        perform_request

        expect(response).to redirect_to(admin_ai_terms_and_conditions_url)
      end
    end
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
      get admin_ai_self_hosted_models_path
    end

    context 'when no self_hosted_model has an api_token set' do
      before do
        create(:ai_self_hosted_model, name: 'test1')
        create(:ai_self_hosted_model, name: 'test2')
      end

      it 'returns a list of AI powered features' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('test1')
        expect(response.body).to include('test2')
        expect(response.body).not_to include('api-key-icon')
      end
    end

    context 'when a self_hosted_model has an api_token set' do
      before do
        create(:ai_self_hosted_model, name: 'test1')
        create(:ai_self_hosted_model, name: 'test2', api_token: 'this_is_a_test')
      end

      it 'returns a list of AI powered features' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('test1')
        expect(response.body).to include('test2')
        expect(response.body).to include('api-key-icon').once
      end
    end

    it_behaves_like 'returns 404'
    it_behaves_like 'must accept terms and conditions'
  end

  describe 'GET #edit' do
    let(:page) { Nokogiri::HTML(response.body) }
    let(:self_hosted_model) do
      create(:ai_self_hosted_model, model: :mixtral)
    end

    subject :perform_request do
      get edit_admin_ai_self_hosted_model_path(self_hosted_model)
    end

    it 'returns a form for existing deployment info' do
      perform_request

      expect(response).to have_gitlab_http_status(:ok)

      expect(page.at('#self_hosted_model_name')['value']).to eq(self_hosted_model.name)
      expect(page.at('#self_hosted_model_model option[@selected="selected"]')['value']).to eq('mixtral')
      expect(page.at('#self_hosted_model_endpoint')['value']).to eq(self_hosted_model.endpoint)
    end

    context 'when attribute api_token is not set' do
      it 'does not show the placeholder' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(page.at('#self_hosted_model_api_token')['value']).to be_nil
        expect(page.at('#self_hosted_model_api_token')['placeholder']).to be_nil
      end
    end

    context 'when attribute api_token is set' do
      let(:self_hosted_model) do
        create(:ai_self_hosted_model, api_token: 'this_is_a_test')
      end

      it 'does not show the placeholder' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(page.at('#self_hosted_model_api_token')['value']).to be_nil
        expect(page.at('#self_hosted_model_api_token')['placeholder']).to eq('*************')
      end
    end

    it_behaves_like 'returns 404'
    it_behaves_like 'must accept terms and conditions'
  end

  describe 'POST #create' do
    let(:params) do
      {
        self_hosted_model: {
          name: 'test',
          model: :mixtral,
          endpoint: 'https://example.com'
        }
      }
    end

    subject :perform_request do
      post admin_ai_self_hosted_models_path, params: params
    end

    it 'updates feature settings' do
      expect { perform_request }.to change { ::Ai::SelfHostedModel.count }.by(1)

      self_hosted_model = ::Ai::SelfHostedModel.last
      expect(self_hosted_model.name).to eq 'test'
      expect(self_hosted_model.model).to eq 'mixtral'
      expect(self_hosted_model.endpoint).to eq 'https://example.com'

      expect(response).to redirect_to(admin_ai_self_hosted_models_url)
    end

    it_behaves_like 'returns 404'
    it_behaves_like 'must accept terms and conditions'
  end

  describe 'PATCH #update' do
    let(:self_hosted_model) do
      create(:ai_self_hosted_model, name: 'test', model: :mixtral)
    end

    let(:params) do
      {
        self_hosted_model: {
          name: 'test_edited',
          model: :mistral,
          endpoint: 'https://example.com',
          api_token: 'this_is_a_test'
        }
      }
    end

    subject :perform_request do
      patch admin_ai_self_hosted_model_path(self_hosted_model), params: params
    end

    it 'updates feature settings' do
      perform_request

      self_hosted_model.reload

      expect(self_hosted_model.name).to eq 'test_edited'
      expect(self_hosted_model.model).to eq 'mistral'
      expect(self_hosted_model.endpoint).to eq 'https://example.com'
      expect(self_hosted_model.api_token).to eq 'this_is_a_test'

      expect(response).to redirect_to(admin_ai_self_hosted_models_url)
    end

    it_behaves_like 'returns 404'
    it_behaves_like 'must accept terms and conditions'
  end

  describe 'DELETE #destroy' do
    before do
      create(:ai_self_hosted_model)
    end

    subject :perform_request do
      delete admin_ai_self_hosted_model_path(::Ai::SelfHostedModel.last)
    end

    it 'deletes the self_hosted_model' do
      expect { perform_request }.to change { ::Ai::SelfHostedModel.count }.by(-1)
      expect(response).to redirect_to(admin_ai_self_hosted_models_url)
    end

    it_behaves_like 'returns 404'
    it_behaves_like 'must accept terms and conditions'
  end
end
