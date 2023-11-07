# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Answer, feature_category: :duo_chat do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:project) { build_stubbed(:project) }

  let(:tools) { [Gitlab::Llm::Chain::Tools::IssueIdentifier] }
  let(:tool_double) { instance_double(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor) }
  let(:request_id) { 'uuid' }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user,
      container: project,
      resource: user,
      ai_request: ai_request_double,
      request_id: request_id
    )
  end

  let(:input) do
    <<-INPUT
      Thought: thought
      Action: IssueIdentifier
      Action Input: Bar
    INPUT
  end

  describe '.from_response' do
    subject(:answer) { described_class.from_response(response_body: input, tools: tools, context: context) }

    before do
      allow(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor).to receive(:new).and_return(tool_double)
    end

    it 'returns intermediate answer with parsed values and a tool' do
      expect(answer.is_final?).to eq(false)
      expect(answer.tool::NAME).to eq('IssueIdentifier')
    end

    context 'when parsed response is final' do
      it 'returns final answer' do
        allow_next_instance_of(Gitlab::Llm::Chain::Parsers::ChainOfThoughtParser) do |parser|
          allow(parser).to receive(:final_answer).and_return(true)
        end

        expect(answer.is_final?).to eq(true)
      end
    end

    context 'when tool is nil' do
      let(:input) do
        <<-INPUT
          Thought: thought
          Action: Nil
          Action Input: Bar
        INPUT
      end

      it 'returns final answer with default response' do
        expect(answer.is_final?).to eq(true)
        expect(answer.content).to eq(described_class.default_final_message)
      end
    end

    context 'when response is empty' do
      let(:input) { '' }

      it 'returns final answer with default response' do
        expect(answer.is_final?).to eq(true)
        expect(answer.content).to eq(described_class.default_final_message)
      end
    end

    context 'when tool does not contain any of expected keyword' do
      let(:input) { 'Here is my freestyle answer.' }

      it 'returns final answer with default response' do
        expect(answer.is_final?).to eq(true)
        expect(answer.content).to eq(input)
      end
    end
  end

  describe '.final_answer' do
    subject(:answer) { described_class.final_answer(context: context, content: "yay!") }

    it 'returns final answer with correct response' do
      expect(answer.is_final?).to eq(true)
      expect(answer.content).to eq("yay!")
      expect(answer.tool).to be_nil
      expect(answer.status).to eq(:ok)
    end
  end

  describe '.error_answer' do
    subject(:answer) { described_class.error_answer(context: context, content: "error") }

    it 'returns final answer with error response' do
      expect(answer.is_final?).to eq(true)
      expect(answer.content).to eq("error")
      expect(answer.tool).to be_nil
      expect(answer.status).to eq(:error)
    end

    it 'tracks a snowplow event' do
      answer

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'error_answer',
        property: 'uuid',
        label: 'gitlab_duo_chat_answer',
        user: user,
        namespace: project
      )
    end
  end

  describe '.default_final_answer' do
    subject(:answer) { described_class.default_final_answer(context: context) }

    it 'returns final answer with the default response' do
      expect(answer.is_final?).to eq(true)
      expect(answer.content).to eq("I don't see how I can help. Please give better instructions!")
      expect(answer.tool).to be_nil
      expect(answer.status).to eq(:ok)
    end

    it 'tracks a snowplow event' do
      answer

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'default_answer',
        property: 'uuid',
        label: 'gitlab_duo_chat_answer',
        user: user,
        namespace: project
      )
    end
  end
end
