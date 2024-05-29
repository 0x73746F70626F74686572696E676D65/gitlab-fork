# frozen_string_literal: true

require_relative '../../shared'

RSpec.shared_examples 'checks for remote_development licensed feature' do
  context 'when remote_development feature is unlicensed' do
    before do
      stub_licensed_features(remote_development: false)
    end

    it 'returns an error' do
      post_graphql(query, current_user: current_user)

      expect_graphql_errors_to_include "'remote_development' licensed feature is not available"
    end
  end
end

RSpec.shared_examples 'checks whether the feature flag is enabled' do
  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(remote_development_namespace_agent_authorization: false)
    end

    it 'returns an error' do
      post_graphql(query, current_user: current_user)

      expect_graphql_errors_to_include "'remote_development_namespace_agent_authorization' feature flag is disabled"
    end
  end
end
