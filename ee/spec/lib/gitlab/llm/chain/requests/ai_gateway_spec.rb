# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Requests::AiGateway, feature_category: :duo_chat do
  let_it_be(:user) { build(:user) }
  let(:tracking_context) { { action: 'chat', request_id: 'uuid' } }

  subject(:instance) { described_class.new(user, tracking_context: tracking_context) }

  describe 'initializer' do
    it 'initializes the AI Gateway client' do
      expect(instance.ai_client.class).to eq(::Gitlab::Llm::AiGateway::Client)
    end
  end

  describe '#request' do
    let(:logger) { instance_double(Gitlab::Llm::Logger) }
    let(:ai_client) { double }
    let(:endpoint) { described_class::ENDPOINT }
    let(:model) { nil }
    let(:expected_model) { described_class::CLAUDE_3_SONNET }
    let(:provider) { :anthropic }
    let(:params) do
      {
        max_tokens_to_sample: 2048,
        stop_sequences: ["\n\nHuman", "Observation:"],
        temperature: 0.1
      }
    end

    let(:user_prompt) { "some user request" }
    let(:options) { { model: model } }
    let(:prompt) { { prompt: user_prompt, options: options } }
    let(:payload) do
      {
        content: user_prompt,
        provider: provider,
        model: expected_model,
        params: params
      }
    end

    let(:body) do
      {
        prompt_components: [{
          type: described_class::DEFAULT_TYPE,
          metadata: {
            source: described_class::DEFAULT_SOURCE,
            version: Gitlab.version_info.to_s
          },
          payload: payload
        }],
        stream: true
      }
    end

    let(:response) { 'Hello World' }

    subject(:request) { instance.request(prompt) }

    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(instance).to receive(:ai_client).and_return(ai_client)
    end

    shared_examples 'performing request to the AI Gateway' do
      it 'returns the response from AI Gateway' do
        expect(ai_client).to receive(:stream).with(endpoint: endpoint, body: body).and_return(response)

        expect(request).to eq(response)
      end
    end

    it 'calls the AI Gateway streaming endpoint and yields response without stripping it' do
      expect(ai_client).to receive(:stream).with(endpoint: endpoint, body: body).and_yield(response)
        .and_return(response)

      expect { |b| instance.request(prompt, &b) }.to yield_with_args(response)
    end

    it_behaves_like 'performing request to the AI Gateway'

    it_behaves_like 'tracks events for AI requests', 4, 2, klass: 'Gitlab::Llm::Anthropic::Client' do
      before do
        allow(ai_client).to receive(:stream).with(endpoint: endpoint, body: body).and_return(response)
      end
    end

    context 'when additional params are passed in as options' do
      let(:options) do
        { temperature: 1, stop_sequences: %W[\n\Foo Bar:], max_tokens_to_sample: 1024, disallowed_param: 1, topP: 1 }
      end

      let(:params) do
        {
          max_tokens_to_sample: 1024,
          stop_sequences: ["\n\Foo", "Bar:"],
          temperature: 1
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when other model is passed' do
      let(:model) { ::Gitlab::Llm::Concerns::AvailableModels::VERTEX_MODEL_CHAT }
      let(:expected_model) { model }
      let(:provider) { :vertex }
      let(:params) { { temperature: 0.1 } } # This checks that non-vertex params lie `stop_sequence` are filtered out

      it_behaves_like 'performing request to the AI Gateway'
      it_behaves_like 'tracks events for AI requests', 4, 2, klass: 'Gitlab::Llm::VertexAi::Client' do
        before do
          allow(ai_client).to receive(:stream).with(endpoint: endpoint, body: body).and_return(response)
        end
      end
    end

    context 'when invalid model is passed' do
      let(:model) { 'test' }

      it 'returns nothing' do
        expect(ai_client).not_to receive(:stream).with(endpoint: endpoint, body: anything)

        expect(request).to eq(nil)
      end
    end
  end
end
