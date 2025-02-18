# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying user chat access', :clean_gitlab_redis_cache, feature_category: :duo_chat do
  include GraphqlHelpers

  let(:fields) do
    <<~GRAPHQL
      duoChatAvailable
    GRAPHQL
  end

  let(:query) do
    graphql_query_for('currentUser', fields)
  end

  subject(:graphql_response) { graphql_data.dig('currentUser', 'duoChatAvailable') }

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
    end

    context 'when user has access to chat' do
      it 'returns true' do
        expect(Ability).to receive(:allowed?).at_least(:once).with(current_user, :access_duo_chat).and_return(true)

        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(true)
      end
    end

    context 'when user does not have access to chat' do
      it 'returns false' do
        expect(Ability).to receive(:allowed?).at_least(:once).with(current_user, :access_duo_chat).and_return(false)

        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(false)
      end
    end

    context 'when feature flag is off' do
      before do
        stub_feature_flags(ai_duo_chat_switch: false)
      end

      it 'returns false' do
        post_graphql(query, current_user: current_user)

        expect(graphql_response).to eq(false)
      end
    end
  end
end
