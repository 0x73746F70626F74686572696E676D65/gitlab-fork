# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying user code suggestions access',
  :clean_gitlab_redis_cache, feature_category: :code_suggestions do
  include GraphqlHelpers

  let(:fields) do
    <<~GRAPHQL
      duoCodeSuggestionsAvailable
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('currentUser', fields)
  end

  subject(:graphql_response) { graphql_data.dig('currentUser', 'duoCodeSuggestionsAvailable') }

  context 'when user is not logged in' do
    let(:current_user) { nil }

    it 'returns an empty response' do
      post_graphql(query, current_user: current_user)

      expect(graphql_response).to be_nil
    end
  end

  context 'when user is logged in' do
    let_it_be(:current_user) { create(:user) }

    before do
      allow(Ability)
        .to receive(:allowed?).and_call_original

      stub_licensed_features(code_suggestions: true)
    end

    context 'when user has access to code suggestions' do
      it 'returns true' do
        expect(CloudConnector::AvailableServices).to receive_message_chain(:find_by_name,
          :allowed_for?).and_return(true)

        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(true)
      end
    end

    context 'when user does not have access to code suggestions' do
      it 'returns false' do
        expect(CloudConnector::AvailableServices).to receive_message_chain(:find_by_name,
          :allowed_for?).and_return(false)

        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(false)
      end
    end

    context 'when feature flag is off' do
      before do
        stub_feature_flags(ai_duo_code_suggestions_switch: false)
      end

      it 'returns false' do
        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(false)
      end
    end
  end
end
