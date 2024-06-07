# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::CodeSuggestionsClient, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:instance_token) { create(:service_access_token, :active) }

  describe "#test_completion" do
    let(:body) { { choices: [{ text: "puts \"Hello World!\"\nend", index: 0, finish_reason: "length" }] } }
    let(:code) { 200 }

    subject(:result) { described_class.new(user).test_completion }

    shared_examples "error response" do |message|
      it "returns an error" do
        expect(result).to eq(message)
      end
    end

    before do
      stub_request(:post, /#{Gitlab::AiGateway.url}/)
        .to_return(status: code, body: body.to_json, headers: { "Content-Type" => "application/json" })
      allow(CloudConnector::AvailableServices).to receive_message_chain(:find_by_name,
        :access_token).and_return(instance_token)
    end

    it 'returns nil if there is no error' do
      expect(result).to be_nil
    end

    context 'when there is not valid token' do
      let(:instance_token) { nil }

      it_behaves_like 'error response', "Access token is missing"
    end

    context 'when response does not contain a valid choice' do
      let(:body) { { choices: [] } }

      it_behaves_like 'error response', "Response doesn't contain a completion"
    end

    context 'when response code is not 200' do
      let(:code) { 401 }
      let(:body) { 'an error' }

      it_behaves_like 'error response', 'AI Gateway returned code 401: "an error"'
    end

    context 'when request raises an error' do
      before do
        stub_request(:post, /#{Gitlab::AiGateway.url}/).to_raise(StandardError.new('an error'))
      end

      it 'tracks an exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))

        result
      end

      it_behaves_like 'error response', 'an error'
    end
  end

  describe '#direct_access_token', :with_cloud_connector do
    include StubRequests

    let(:expected_token) { 'user token' }
    let(:expected_response) { { 'token' => expected_token } }
    let(:response_body) { expected_response.to_json }
    let(:http_status) { 200 }
    let(:client) { described_class.new(user) }
    let(:gitlab_global_id) { API::Helpers::GlobalIds::Generator.new.generate(user) }
    let(:expected_request_headers) do
      {
        'X-Gitlab-Instance-Id' => gitlab_global_id.first,
        'X-Gitlab-Global-User-Id' => gitlab_global_id.second,
        'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
        'X-Gitlab-Realm' => Gitlab::CloudConnector::GITLAB_REALM_SELF_MANAGED,
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{instance_token.token}",
        'Content-Type' => 'application/json',
        'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id
      }
    end

    subject(:result) { client.direct_access_token }

    before do
      stub_request(:post, Gitlab::AiGateway.access_token_url)
        .with(
          body: nil,
          headers: expected_request_headers
        )
        .to_return(
          status: http_status,
          body: response_body,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it { is_expected.to match({ status: :success, token: expected_token }) }

    context 'when instance token is missing' do
      before do
        allow(client).to receive(:access_token).and_return(nil)
      end

      it { is_expected.to match(a_hash_including(status: :error)) }
    end

    context 'when response fails' do
      let(:http_status) { 500 }

      it { is_expected.to match(a_hash_including(status: :error)) }
    end

    context 'when token is not included in response' do
      let(:response_body) { { foo: :bar }.to_json }

      it { is_expected.to match(a_hash_including(status: :error)) }
    end
  end
end
