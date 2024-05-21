# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::FeatureSettingsController, :enable_admin_mode, feature_category: :custom_models do
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  shared_examples 'returns 404 when feature is disabled' do
    context 'when ai_custom_model feature flag is disabled' do
      before do
        stub_feature_flags(ai_custom_model: false)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when gitlab com subscription enabled' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when self_managed_code_suggestions is disabled' do
      before do
        stub_feature_flags(self_managed_code_suggestions: false)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when current licences is not paid' do
      before do
        allow(License).to receive_message_chain(:current, :paid?).and_return(false)
      end

      it 'returns 404' do
        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #index' do
    it 'returns a list of AI powered features' do
      create(:ai_feature_setting)

      get admin_ai_feature_settings_path

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to match(
        /Code Generations.+Self-Hosted Model \(Mistral\)/m
      )
      expect(response.body).to match(
        /Code Completions.+GitLab AI Vendor/m
      )
    end

    it_behaves_like 'returns 404 when feature is disabled' do
      let(:perform_request) { get admin_ai_feature_settings_path }
    end
  end

  describe 'GET #edit' do
    let(:page) { Nokogiri::HTML(response.body) }

    it 'returns a form for existing feature' do
      create(:ai_feature_setting, feature: :code_generations)

      get edit_admin_ai_feature_setting_path(:code_generations)

      expect(response).to have_gitlab_http_status(:ok)

      radio_button = page.at('#feature_setting_provider_self_hosted')
      expect(radio_button.attributes['checked'].value).to eq('checked')
    end

    it 'initializes a form for a new feature' do
      get edit_admin_ai_feature_setting_path(:code_completions)

      expect(response).to have_gitlab_http_status(:ok)

      radio_button = page.at('#feature_setting_provider_vendored')
      expect(radio_button.attributes['checked'].value).to eq('checked')
    end

    it_behaves_like 'returns 404 when feature is disabled' do
      let(:perform_request) { get edit_admin_ai_feature_setting_path(:code_completions) }
    end
  end

  describe 'POST #create' do
    let(:self_hosted_model) { create(:ai_self_hosted_model) }
    let(:params) do
      {
        feature_setting: {
          feature: :code_completions,
          provider: :self_hosted,
          ai_self_hosted_model_id: self_hosted_model.id
        }
      }
    end

    it 'stores feature settings' do
      expect { post admin_ai_feature_settings_path, params: params }.to change { ::Ai::FeatureSetting.count }.by(1)

      feature_setting = ::Ai::FeatureSetting.last
      expect(feature_setting).to be_self_hosted
      expect(feature_setting.self_hosted_model).to eq(self_hosted_model)
      expect(response).to redirect_to(admin_ai_feature_settings_url)
    end

    context 'when the settings are invalid' do
      let(:params) do
        {
          feature_setting: {
            feature: :code_completions,
            provider: :self_hosted
          }
        }
      end

      it 'renders edit page' do
        expect { post admin_ai_feature_settings_path, params: params }.not_to change { ::Ai::FeatureSetting.count }

        expect(response.body).to include('Edit Code Completions')
      end
    end

    it_behaves_like 'returns 404 when feature is disabled' do
      let(:params) do
        { feature_setting: { feature: :code_completions, provider: :vendored } }
      end

      let(:perform_request) { post admin_ai_feature_settings_path, params: params }
    end
  end

  describe 'PATCH #update' do
    let(:feature_setting) { create(:ai_feature_setting) }
    let(:params) do
      {
        feature_setting: {
          feature: :code_completions,
          provider: :vendored,
          ai_self_hosted_model_id: nil
        }
      }
    end

    it 'updates feature settings' do
      patch admin_ai_feature_setting_path(feature_setting), params: params

      feature_setting.reload

      expect(feature_setting).to be_vendored
      expect(feature_setting.self_hosted_model).to be_nil
      expect(response).to redirect_to(admin_ai_feature_settings_url)
    end

    context 'when the settings are invalid' do
      let(:params) do
        {
          feature_setting: {
            feature: :code_completions,
            provider: :self_hosted,
            ai_self_hosted_model_id: nil
          }
        }
      end

      it 'renders edit page' do
        patch admin_ai_feature_setting_path(feature_setting), params: params

        expect(response.body).to include('Edit Code Completions')
      end
    end

    it_behaves_like 'returns 404 when feature is disabled' do
      let(:feature_setting) { create(:ai_feature_setting, provider: :vendored, self_hosted_model: nil) }
      let(:params) do
        { feature_setting: { feature: :code_completions, provider: :vendored } }
      end

      let(:perform_request) do
        patch admin_ai_feature_setting_path(feature_setting), params: params
      end
    end
  end
end
