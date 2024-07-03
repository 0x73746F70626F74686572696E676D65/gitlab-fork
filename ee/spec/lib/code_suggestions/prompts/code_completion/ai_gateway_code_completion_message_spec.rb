# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage, feature_category: :custom_models do
  let(:dummy_class) do
    Class.new(described_class) do
      def prompt
        "dummy prompt"
      end
    end
  end

  let(:params) do
    {
      model_endpoint: 'http://example.com/endpoint',
      model_name: 'example_model'
    }
  end

  let(:dummy_message) { dummy_class.new(params) }

  describe '#request_params' do
    it 'returns the correct request params' do
      expected_params = {
        model_provider: 'litellm',
        prompt_version: 2,
        prompt: 'dummy prompt',
        model_endpoint: 'http://example.com/endpoint',
        model_name: 'example_model'
      }

      expect(dummy_message.request_params).to eq(expected_params)
    end
  end

  describe '#prompt' do
    it 'raises NotImplementedError for the abstract class' do
      expect do
        described_class.new(params).send(:prompt)
      end.to raise_error(NotImplementedError, "#{described_class} has not implemented method prompt")
    end
  end
end
