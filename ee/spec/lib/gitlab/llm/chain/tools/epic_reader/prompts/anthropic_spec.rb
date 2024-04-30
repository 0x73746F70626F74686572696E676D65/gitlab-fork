# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::EpicReader::Prompts::Anthropic, feature_category: :duo_chat do
  let(:options) do
    {
      input: 'foo?',
      suggestions: "some suggestions"
    }
  end

  describe '.prompt' do
    it 'returns prompt' do
      prompt = described_class.prompt(options)[:prompt]

      expect(prompt).to include('Human:')
      expect(prompt).to include('Assistant:')
      expect(prompt).to include("\"ResourceIdentifierType\": \"")
      expect(prompt).to include('some suggestions')
      expect(prompt).to include('foo?')
      expect(prompt).to include('You can fetch information about a resource called: an epic.')
    end
  end

  describe '.claude_3_prompt' do
    context "when calling claude 3 prompt" do
      it "returns prompt" do
        prompt = described_class.claude_3_prompt(options)[:prompt]
        expect(prompt.length).to eq(3)

        expect(prompt[0][:role]).to eq(:system)
        expect(prompt[0][:content]).to eq(system_prompt)

        expect(prompt[1][:role]).to eq(:user)
        expect(prompt[1][:content]).to eq(options[:input])

        expect(prompt[2][:role]).to eq(:assistant)
        expect(prompt[2][:content]).to include(options[:suggestions], "\"ResourceIdentifierType\": \"")
      end

      it "calls with haiku model" do
        model = described_class.claude_3_prompt(options)[:options][:model]

        expect(model).to eq(::Gitlab::Llm::AiGateway::Client::CLAUDE_3_HAIKU)
      end
    end
  end

  def system_prompt
    ::Gitlab::Llm::Chain::Tools::EpicIdentifier::Executor::SYSTEM_PROMPT[1]
  end
end
