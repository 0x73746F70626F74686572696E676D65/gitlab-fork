# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphqlController, feature_category: :api do
  include GraphqlHelpers
  let(:user) { create(:user) }
  let(:query) { '{ __typename }' }

  subject(:response) { post :execute, params: { query: query, access_token: token.token } }

  context 'when user uses an ai_features scope API token' do
    let(:token) { create(:personal_access_token, user: user, scopes: [:ai_features]) }

    it 'succeeds' do
      expect(response).to be_successful
    end

    context 'when allow_ai_features_token_for_graphql_ai_features is disabled' do
      before do
        stub_feature_flags(allow_ai_features_token_for_graphql_ai_features: false)
      end

      it 'fails' do
        expect(response).not_to be_successful
      end
    end

    context 'when graphql_minimal_auth_methods is disabled' do
      before do
        stub_feature_flags(graphql_minimal_auth_methods: false)
      end

      it 'fails' do
        expect(response).not_to be_successful
      end
    end
  end

  context 'when user uses a read_user scope API token' do
    let(:token) { create(:personal_access_token, user: user, scopes: [:read_user]) }

    it 'fails' do
      expect(response).not_to be_successful
    end
  end
end
