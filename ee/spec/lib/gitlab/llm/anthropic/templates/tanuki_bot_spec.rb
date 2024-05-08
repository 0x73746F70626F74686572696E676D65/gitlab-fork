# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Templates::TanukiBot, feature_category: :duo_chat do
  let(:user) { build(:user) }
  let(:question) { 'How to do something?' }
  let(:documents) { [{ id: 1, content: 'foo' }, { id: 2, content: 'bar' }] }

  subject(:final_prompt) { described_class.final_prompt(user, question: question, documents: documents) }

  describe '#final_prompt' do
    context 'with ai_claude_3_for_docs disabled' do
      before do
        stub_feature_flags(ai_claude_3_for_docs: false)
      end

      it "returns prompt" do
        expect(final_prompt[:prompt]).to include('Human:')
        expect(final_prompt.dig(:options, :model)).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_2_1)
      end
    end

    context 'with ai_claude_3_for_docs enabled' do
      it "returns prompt" do
        prompt = final_prompt[:prompt]

        expect(prompt.length).to eq(2)
        expect(prompt[0][:role]).to eq(:user)
        expect(prompt[0][:content]).to include(question)
        expect(prompt[1][:role]).to eq(:assistant)
        expect(prompt[1][:content]).to include('FINAL ANSWER:')

        expect(final_prompt.dig(:options, :model)).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_SONNET)
      end
    end
  end
end
