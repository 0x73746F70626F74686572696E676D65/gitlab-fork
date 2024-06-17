# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::Base, feature_category: :ai_abstraction_layer do
  let(:subclass) { Class.new(described_class) }
  let(:user) { build(:user) }
  let(:resource) { build(:issue) }
  let(:ai_action) { 'test_action' }
  let(:prompt_message) { build(:ai_message, ai_action: ai_action, user: user, resource: resource) }
  let(:agent_name) { 'test_agent' }
  let(:inputs) { { prompt: "What's your name?" } }
  let(:response) { instance_double(HTTParty::Response, body: "I'm Duo!") }
  let(:response_modifier) { instance_double(Gitlab::Llm::AiGateway::ResponseModifiers::Base) }
  let(:response_service) { instance_double(Gitlab::Llm::GraphqlSubscriptionResponseService) }
  let(:tracking_context) { { action: ai_action, request_id: prompt_message.request_id } }
  let(:client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:response_options) do
    prompt_message.to_h.slice(:request_id, :client_subscription_id, :ai_action, :agent_version_id)
  end

  subject(:completion) { subclass.new(prompt_message, nil) }

  describe 'required methods' do
    it { expect { completion.agent_name }.to raise_error(NotImplementedError) }
    it { expect { completion.inputs }.to raise_error(NotImplementedError) }
  end

  describe '#execute' do
    before do
      allow(completion).to receive(:agent_name).and_return(agent_name)
      allow(completion).to receive(:inputs).and_return(inputs)

      allow(Gitlab::Llm::AiGateway::Client).to receive(:new)
        .with(user, service_name: ai_action.to_sym, tracking_context: tracking_context).and_return(client)
      allow(client).to receive(:complete).with(endpoint: "/v1/agents/#{ai_action}/#{agent_name}", body: inputs)
        .and_return(response)
      allow(Gitlab::Llm::AiGateway::ResponseModifiers::Base).to receive(:new).with(response)
        .and_return(response_modifier)
      allow(Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new)
        .with(user, resource, response_modifier, options: response_options).and_return(response_service)
    end

    let(:result) { { status: :success } }

    subject(:execute) { completion.execute }

    it 'executes the response service and returns its result' do
      expect(response_service).to receive(:execute).and_return(result)

      expect(execute).to be(result)
    end
  end
end
