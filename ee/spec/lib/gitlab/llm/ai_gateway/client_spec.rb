# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Client, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:active_token) { create(:service_access_token, :active) }

  let(:options) { {} }
  let(:expected_request_body) { default_body_params }
  let(:gitlab_global_id) { API::Helpers::GlobalIds::Generator.new.generate(user) }

  let(:expected_access_token) { active_token.token }
  let(:expected_gitlab_realm) { Gitlab::CloudConnector::GITLAB_REALM_SELF_MANAGED }
  let(:expected_gitlab_host_name) { Gitlab.config.gitlab.host }
  let(:expected_instance_id) { gitlab_global_id.first }
  let(:expected_user_id) { gitlab_global_id.second }
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

  let(:model) { described_class::CLAUDE_3_SONNET }
  let(:provider) { 'anthropic' }
  let(:prompt) { 'anything' }

  let(:default_body_params) do
    {
      prompt_components: [{
        type: described_class::DEFAULT_TYPE,
        metadata: {
          source: described_class::DEFAULT_SOURCE,
          version: Gitlab.version_info.to_s
        },
        payload: {
          content: prompt,
          provider: provider,
          model: model
        }
      }],
      stream: false
    }
  end

  let(:response_text) { "Completion Response" }
  let(:expected_response) do
    {
      "response" => response_text,
      "metadata" => {
        "provider" => "anthropic",
        "model" => model,
        "timestamp" => 1000000000 # The number of seconds passed since epoch
      }
    }
  end

  let(:request_url) { "#{Gitlab::AiGateway.url}/v1/chat/agent" }
  let(:tracking_context) { { request_id: 'uuid', action: 'chat' } }
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
        body: expected_request_body,
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

  shared_examples 'tracks events with provider for AI requests' do |prompt_size, response_size, klass|
    it 'tracks a snowplow event' do
      subject

      expect_snowplow_event(
        category: klass.to_s,
        action: 'tokens_per_user_request_prompt',
        property: 'uuid',
        label: 'chat',
        user: user,
        value: prompt_size
      )

      expect_snowplow_event(
        category: klass.to_s,
        action: 'tokens_per_user_request_response',
        property: 'uuid',
        label: 'chat',
        user: user,
        value: response_size
      )
    end
  end

  describe '#complete' do
    subject(:complete) do
      described_class.new(user, tracking_context: tracking_context).complete(prompt: 'anything', **options)
    end

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
          stub_request(:post, "#{Gitlab::AiGateway.url}/v1/chat/agent")
            .to_return(status: 429, body: '', headers: response_headers)
            .then.to_return(status: 200, body: response_body, headers: response_headers)

          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'tracks events with provider for AI requests', 2, 4, 'Gitlab::Llm::Anthropic::Client'
      end
    end

    it_behaves_like 'tracks events with provider for AI requests', 2, 4, 'Gitlab::Llm::Anthropic::Client'

    it 'returns response' do
      expect(Gitlab::HTTP).to receive(:post)
        .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
        .and_call_original
      expect(complete.parsed_response).to eq(expected_response)
    end

    it 'logs request and response' do
      expect(Gitlab::HTTP).to receive(:post)
                                .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
                                .and_call_original
      complete

      expect(logger).to have_received(:info_or_debug)
        .with(user, message: "Performing request to AI Gateway", options: options, prompt: prompt)
      expect(logger).to have_received(:info_or_debug)
        .with(user, message: "Received response from AI Gateway", response: response_text)
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
      let(:request_url) { "https://cloud.gitlab.com/ai/v1/chat/agent" }

      it 'sends requests through Cloud Connector load balancer' do
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when AI_GATEWAY_URL is set' do
      let(:request_url) { "http://127.0.0.1:5000/v1/chat/agent" }

      it 'sends requests to this host instead' do
        stub_env('AI_GATEWAY_URL', "http://127.0.0.1:5000")

        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when passing stream: true' do
      let(:options) { { stream: true } }
      let(:expected_request_body) { default_body_params }

      it 'does not pass stream: true as we do not want to retrieve SSE events' do
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'with specified url' do
      let(:request_url) { "#{Gitlab::AiGateway.url}/dynamic_url" }
      let(:options) { { endpoint_url: '/dynamic_url' } }

      it 'returns response' do
        expect(Gitlab::HTTP).to receive(:post)
                                  .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
                                  .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when other model is passed' do
      let(:model) { ::Gitlab::Llm::Concerns::AvailableModels::VERTEX_MODEL_CHAT }
      let(:provider) { 'vertex' }
      let(:options) { { model: model } }

      it 'returns expected response' do
        expect(Gitlab::HTTP).to receive(:post)
                                  .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
                                  .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end

      it_behaves_like 'tracks events with provider for AI requests', 2, 4, 'Gitlab::Llm::VertexAi::Client'
    end

    context 'when invalid model is passed' do
      let(:model) { 'test' }
      let(:options) { { model: model } }

      it 'returns nothing' do
        expect(Gitlab::HTTP).not_to receive(:post)
                                  .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
                                  .and_call_original
        expect(complete).to eq(nil)
      end
    end
  end

  describe '#stream' do
    subject { described_class.new(user, tracking_context: tracking_context).stream(prompt: 'anything', **options) }

    context 'when streaming the request' do
      let(:response_body) { expected_response }
      let(:options) { { stream: true } }
      let(:expected_request_body) { default_body_params.merge(stream: true) }

      context 'when response is successful' do
        let(:expected_response) { 'Hello' }

        it 'provides parsed streamed response' do
          expect { |b| described_class.new(user).stream(prompt: 'anything', **options, &b) }.to yield_with_args('Hello')
        end

        it 'returns response' do
          expect(Gitlab::HTTP).to receive(:post)
            .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
            .and_call_original

          expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq("Hello")
        end

        context 'when setting a timeout' do
          let(:options) { { timeout: 50.seconds } }

          it 'uses the timeout for the request' do
            expect(Gitlab::HTTP).to receive(:post)
              .with(anything, hash_including(timeout: 50.seconds))
              .and_call_original

            described_class.new(user).stream(prompt: 'anything', **options)
          end
        end

        it_behaves_like 'tracks events with provider for AI requests', 2, 1, 'Gitlab::Llm::Anthropic::Client'
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
          expect { |b| described_class.new(user).stream(prompt: 'anything', **options, &b) }
            .to yield_successive_args('Hello', ' ', 'World')
        end

        it 'returns response' do
          expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq(expected_response)
        end

        context 'when additional params are passed in as options' do
          context 'for Anthropic' do
            let(:options) do
              { temperature: 1, stop_sequences: %W[\n\nHuman Observation:], max_tokens_to_sample: 1024,
                disallowed_param: 1, topP: 1 }
            end

            let(:expected_response) { "Hello World" }

            before do
              allow(Gitlab::HTTP).to receive(:post).and_return(success)
                .and_yield("Hello").and_yield(" ").and_yield("World")
            end

            it 'passes the allowed options as params' do
              expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq(expected_response)

              expect(Gitlab::HTTP).to have_received(:post).with(
                anything,
                hash_including(
                  body: including(
                    '"temperature":1',
                    '"stop_sequences":["\n\nHuman","Observation:"]',
                    '"max_tokens_to_sample":1024'
                  )
                )
              )
            end

            it 'does not pass the disallowed options as params' do
              expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq(expected_response)

              expect(Gitlab::HTTP).to have_received(:post).with(
                anything,
                hash_excluding(
                  body: include('disallowed_param', 'topP')
                )
              )
            end
          end

          context 'for Vertex' do
            let(:options) do
              { temperature: 1, maxOutputTokens: 1024, topK: 10, topP: 10,
                disallowed_param: 1, max_tokens_to_sample: 1024,
                model: ::Gitlab::Llm::Concerns::AvailableModels::VERTEX_MODEL_CHAT }
            end

            let(:expected_response) { "Hello World" }

            before do
              allow(Gitlab::HTTP).to receive(:post).and_return(success)
                                                   .and_yield("Hello").and_yield(" ").and_yield("World")
            end

            it 'passes the allowed options as params' do
              expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq(expected_response)

              expect(Gitlab::HTTP).to have_received(:post).with(
                anything,
                hash_including(
                  body: including(
                    '"temperature":1',
                    '"topK":10',
                    '"topP":10',
                    '"maxOutputTokens":1024'
                  )
                )
              )
            end

            it 'does not pass the disallowed options as params' do
              expect(described_class.new(user).stream(prompt: 'anything', **options)).to eq(expected_response)

              expect(Gitlab::HTTP).to have_received(:post).with(
                anything,
                hash_excluding(
                  body: include('disallowed_param', 'max_tokens_to_sample')
                )
              )
            end

            it_behaves_like 'tracks events with provider for AI requests', 2, 2, 'Gitlab::Llm::VertexAi::Client'
          end
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
          expect { described_class.new(user).stream(prompt: 'anything', **options) }
            .to raise_error(Gitlab::Llm::AiGateway::Client::ConnectionError)

          expect(logger).to have_received(:error).with(message: "Received error from AI gateway", response: "")
        end
      end
    end
  end
end
