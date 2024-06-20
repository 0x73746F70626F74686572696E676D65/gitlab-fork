# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a self-hosted model', feature_category: :custom_models do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }

  let(:input) do
    {
      "name" => 'ollama1-mistral',
      "endpoint" => 'http://localhost:8080',
      "model" => 'MISTRAL',
      "api_token" => "test_api_token"
    }
  end

  let(:mutation) { graphql_mutation(:ai_self_hosted_model_create, input) }
  let(:mutation_response) { graphql_mutation_response(:ai_self_hosted_model_create) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'it calls the manage_ai_settings policy' do
    it 'calls the manage_ai_settings policy' do
      allow(::Ability).to receive(:allowed?).and_call_original

      expect(::Ability).to receive(:allowed?)
                             .with(current_user, :manage_ai_settings)

      request
    end
  end

  context 'when the ai_custom_model FF is disabled' do
    before do
      stub_feature_flags(ai_custom_model: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user is not allowed to write changes' do
    let(:current_user) { create(:user) }

    it_behaves_like 'it calls the manage_ai_settings policy'
    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when user is allowed to write changes' do
    let(:expected_result) do
      {
        "name" => 'ollama1-mistral',
        "endpoint" => 'http://localhost:8080',
        "model" => 'mistral',
        "hasApiToken" => true
      }
    end

    it_behaves_like 'it calls the manage_ai_settings policy'

    it 'creates a self-hosted model' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['selfHostedModel']).to include(**expected_result)
    end
  end
end
