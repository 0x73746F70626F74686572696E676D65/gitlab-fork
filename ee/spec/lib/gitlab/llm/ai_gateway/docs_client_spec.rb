# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::DocsClient, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:token) { create(:service_access_token, :active) }

  let(:options) { {} }
  let(:expected_request_body) { default_body_params }

  let(:expected_access_token) { token.token }
  let(:expected_gitlab_realm) { Gitlab::CloudConnector::GITLAB_REALM_SELF_MANAGED }
  let(:expected_gitlab_host_name) { Gitlab.config.gitlab.host }
  let(:expected_instance_id) { Gitlab::GlobalAnonymousId.instance_id }
  let(:expected_user_id) { Gitlab::GlobalAnonymousId.user_id(user) }
  let(:expected_request_headers) do
    {
      'X-Gitlab-Instance-Id' => expected_instance_id,
      'X-Gitlab-Global-User-Id' => expected_user_id,
      'X-Gitlab-Host-Name' => expected_gitlab_host_name,
      'X-Gitlab-Realm' => expected_gitlab_realm,
      'X-Gitlab-Authentication-Type' => 'oidc',
      'Authorization' => "Bearer #{expected_access_token}",
      'Content-Type' => 'application/json',
      'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id
    }
  end

  let(:default_body_params) do
    {
      type: described_class::DEFAULT_TYPE,
      metadata: {
        source: described_class::DEFAULT_SOURCE,
        version: Gitlab.version_info.to_s
      },
      payload: {
        query: "anything"
      }
    }
  end

  let(:expected_response) do
    { "foo" => "bar" }
  end

  let(:request_url) { "#{Gitlab::AiGateway.url}/v1/search/gitlab-docs" }
  let(:tracking_context) { { request_id: 'uuid', action: 'chat' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }

  include StubRequests

  describe '#search', :with_cloud_connector do
    before do
      stub_request(:post, request_url)
        .with(
          body: expected_request_body,
          headers: expected_request_headers
        )
        .to_return(
          status: http_status,
          body: response_body,
          headers: response_headers
        )
    end

    subject(:result) do
      described_class.new(user, tracking_context: tracking_context).search(query: 'anything', **options)
    end

    it 'returns response', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/463071' do
      expect(Gitlab::HTTP).to receive(:post).with(
        anything,
        hash_including(timeout: described_class::DEFAULT_TIMEOUT)
      ).and_call_original
      expect(result.parsed_response).to eq(expected_response)
    end

    context 'when token is expired' do
      before do
        token.update!(expires_at: 1.day.ago)
      end

      it 'returns empty hash' do
        expect(Gitlab::HTTP).not_to receive(:post)
        expect(result).to eq(nil)
      end
    end
  end
end
