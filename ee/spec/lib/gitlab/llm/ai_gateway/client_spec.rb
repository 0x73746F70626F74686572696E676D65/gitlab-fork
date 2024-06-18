# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Client, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:active_token) { create(:service_access_token, :active) }

  let(:expected_body) { { prompt: 'anything' } }
  let(:timeout) { described_class::DEFAULT_TIMEOUT }
  let(:expected_access_token) { active_token.token }
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

  let(:expected_response) { { "response" => "Response" } }
  let(:endpoint) { '/v1/test' }
  let(:request_url) { "#{Gitlab::AiGateway.url}#{endpoint}" }
  let(:tracking_context) { { request_id: 'uuid', action: 'test' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }
  let(:logger) { instance_double('Gitlab::Llm::Logger') }

  before do
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    allow(logger).to receive(:info_or_debug)
    allow(logger).to receive(:info)

    stub_request(:post, request_url)
      .with(
        body: expected_body,
        headers: expected_request_headers
      )
      .to_return(
        status: http_status,
        body: response_body,
        headers: response_headers
      )

    allow(CloudConnector::AvailableServices).to receive_message_chain(:find_by_name,
      :access_token).and_return(expected_access_token)
  end

  subject(:ai_client) { described_class.new(user, service_name: :test, tracking_context: tracking_context) }

  describe '#complete' do
    subject(:complete) { ai_client.complete(endpoint: endpoint, body: expected_body) }

    context 'when measuring request success' do
      let(:client) { :ai_gateway }

      it_behaves_like 'measured Llm request'

      context 'when request raises an exception' do
        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError)
        end

        it_behaves_like 'measured Llm request with error', StandardError
      end

      context 'when request is retried' do
        let(:http_status) { 429 }

        before do
          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request with error', Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError
      end

      context 'when request is retried once' do
        before do
          stub_request(:post, "#{Gitlab::AiGateway.url}#{endpoint}")
            .to_return(status: 429, body: '', headers: response_headers)
            .then.to_return(status: 200, body: response_body, headers: response_headers)

          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request'
      end
    end

    it 'returns response' do
      expect(Gitlab::HTTP).to receive(:post)
        .with(anything, hash_including(timeout: timeout))
        .and_call_original
      expect(complete.parsed_response).to eq(expected_response)
    end

    it 'logs request and response' do
      expect(Gitlab::HTTP).to receive(:post)
                                .with(anything, hash_including(timeout: timeout))
                                .and_call_original
      complete

      expect(logger).to have_received(:info_or_debug)
        .with(user, message: "Performing request to AI Gateway", body: expected_body, timeout: timeout,
          stream: false)
      expect(logger).to have_received(:info_or_debug)
        .with(user, message: "Received response from AI Gateway", response: expected_response)
    end

    context 'when calling AI Gateway with Claude 2.1 model' do
      let(:model) { Gitlab::Llm::Concerns::AvailableModels::CLAUDE_2_1 }
      let(:options) { { model: model } }

      it 'returns expected response' do
        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
          .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when AI_GATEWAY_URL is not set' do
      let(:request_url) { "https://cloud.gitlab.com/ai#{endpoint}" }

      it 'sends requests through Cloud Connector load balancer' do
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when AI_GATEWAY_URL is set' do
      let(:request_url) { "http://127.0.0.1:5000#{endpoint}" }

      it 'sends requests to this host instead' do
        stub_env('AI_GATEWAY_URL', "http://127.0.0.1:5000")

        expect(complete.parsed_response).to eq(expected_response)
      end
    end
  end

  describe '#stream' do
    subject { ai_client.stream(endpoint: endpoint, body: expected_body) }

    context 'when streaming the request' do
      let(:response_body) { expected_response }

      context 'when response is successful' do
        let(:expected_response) { 'Hello' }

        it 'provides parsed streamed response' do
          expect { |b| ai_client.stream(endpoint: endpoint, body: expected_body, &b) }.to yield_with_args('Hello')
        end

        it 'returns response' do
          expect(Gitlab::HTTP).to receive(:post)
            .with(anything, hash_including(stream_body: true, timeout: timeout))
            .and_call_original

          expect(ai_client.stream(endpoint: endpoint, body: expected_body)).to eq("Hello")
        end

        context 'when setting a timeout' do
          it 'uses the timeout for the request' do
            expect(Gitlab::HTTP).to receive(:post)
              .with(anything, hash_including(stream_body: true, timeout: 50.seconds))
              .and_call_original

            ai_client.stream(endpoint: endpoint, body: expected_body, timeout: 50.seconds)
          end
        end
      end

      context 'when response contains multiple events' do
        let(:expected_response) { "Hello World" }
        let(:success) do
          instance_double(HTTParty::Response,
            code: 200,
            success?: true,
            parsed_response: response_body,
            headers: response_headers,
            body: response_body
          )
        end

        before do
          allow(Gitlab::HTTP).to receive(:post).and_return(success)
            .and_yield("Hello").and_yield(" ").and_yield("World")
        end

        it 'provides parsed streamed response' do
          expect { |b| ai_client.stream(endpoint: endpoint, body: expected_body, &b) }
            .to yield_successive_args('Hello', ' ', 'World')
        end

        it 'returns response' do
          expect(ai_client.stream(endpoint: endpoint, body: expected_body)).to eq(expected_response)
        end
      end

      context 'when response is not successful' do
        let(:response_body) { expected_response.to_json }
        let(:failure) do
          instance_double(HTTParty::Response,
            code: 400,
            success?: false,
            parsed_response: response_body,
            headers: response_headers
          )
        end

        before do
          allow(Gitlab::HTTP).to receive(:post).and_return(failure)
          allow(logger).to receive(:error)
        end

        it 'raises error' do
          expect { ai_client.stream(endpoint: endpoint, body: expected_body) }
            .to raise_error(Gitlab::Llm::AiGateway::Client::ConnectionError)

          expect(logger).to have_received(:error).with(message: "Received error from AI gateway", response: "")
        end
      end
    end
  end
end
