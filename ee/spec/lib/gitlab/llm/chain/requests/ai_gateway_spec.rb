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

    context 'when alternative service name is passed' do
      it 'creates ai gateway client with different service name' do
        expect(::Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          service_name: :alternative,
          tracking_context: tracking_context
        )

        described_class.new(user, service_name: :alternative, tracking_context: tracking_context)
      end
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

    context 'when unit primitive is passed' do
      let(:endpoint) { "#{described_class::BASE_ENDPOINT}/test" }

      subject(:request) { instance.request(prompt, unit_primitive: :test) }

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

    context 'when user is using a Self-hosted model' do
      let!(:ai_feature) { create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat) }
      let!(:self_hosted_model) { create(:ai_self_hosted_model, api_token: 'test_token') }
      let(:expected_model) { self_hosted_model.model.to_s }

      let(:payload) do
        {
          content: user_prompt,
          provider: :litellm,
          model: expected_model,
          model_endpoint: self_hosted_model.endpoint,
          model_api_key: self_hosted_model.api_token,
          params: params
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when request is sent for a new ReAct Duo Chat prompt' do
      let(:endpoint) { described_class::CHAT_V2_ENDPOINT }

      let(:prompt) { { prompt: user_prompt, options: options } }

      let(:options) do
        {
          agent_scratchpad: [],
          single_action_agent: true,
          current_resource_type: "issue",
          current_resource_content: "string"
        }
      end

      let(:body) do
        {
          prompt: user_prompt,
          options: {
            chat_history: "",
            agent_scratchpad: {
              agent_type: "react",
              steps: []
            },
            context: {
              type: "issue",
              content: "string"
            }
          }
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when request is sent for a new ReAct Duo Chat prompt withouth context params' do
      let(:endpoint) { described_class::CHAT_V2_ENDPOINT }

      let(:prompt) { { prompt: user_prompt, options: options } }

      let(:options) do
        {
          agent_scratchpad: [],
          single_action_agent: true
        }
      end

      let(:body) do
        {
          prompt: user_prompt,
          options: {
            chat_history: "",
            agent_scratchpad: {
              agent_type: "react",
              steps: []
            }
          }
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end
  end
end
