# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'List of self-hosted LLM servers.', feature_category: :custom_models do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }

  let! :model_params do
    [
      { name: 'ollama1-mistral', model: :mistral },
      { name: 'vllm-mixtral', model: :mixtral, api_token: "test_api_token" },
      { name: 'ollama2-mistral', model: :mistral }
    ]
  end

  let! :self_hosted_models do
    model_params.map { |params| create(:ai_self_hosted_model, **params) }
  end

  let :expected_data do
    self_hosted_models.map do |self_hosted|
      {
        "id" => self_hosted.to_global_id.to_s,
        "name" => self_hosted.name,
        "model" => self_hosted.model.to_s,
        "endpoint" => self_hosted.endpoint,
        "hasApiToken" => self_hosted.api_token.present?
      }
    end
  end

  let(:ai_self_hosted_models_data) { graphql_data_at(:aiSelfHostedModels, :nodes) }

  let(:query) do
    %(
    query SelfHostedModel {
      aiSelfHostedModels {
        nodes {
          id
          name
          model
          endpoint
          hasApiToken
        }
      }
    }
    )
  end

  subject(:request) { post_graphql(query, current_user: current_user) }

  context 'when user has the required authorization' do
    let(:expect_to_be_authorized) { true }

    it 'returns the self-hosted model data' do
      request

      expect(ai_self_hosted_models_data).to include(*expected_data)
    end

    it_behaves_like 'performs the right authorization'
  end

  context 'when user is not an admin' do
    let_it_be(:current_user) { create(:user) }
    let(:expect_to_be_authorized) { true }

    it 'does not return self-hosted model data' do
      request

      expect(ai_self_hosted_models_data).to be_nil
    end

    it_behaves_like 'performs the right authorization'
  end

  context 'when the ai_custom_model FF is disabled' do
    before do
      stub_feature_flags(ai_custom_model: false)
    end

    it 'does not return self-hosted model data' do
      request

      expect(ai_self_hosted_models_data).to be_nil
    end
  end
end
