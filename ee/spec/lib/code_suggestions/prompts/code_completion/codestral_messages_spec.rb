# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::CodestralMessages, feature_category: :custom_models do
  let(:prompt_version) { 2 }
  let(:language) { instance_double(CodeSuggestions::ProgrammingLanguage) }
  let(:language_name) { 'Python' }

  let(:prefix) do
    <<~PREFIX
def hello_world():
    PREFIX
  end

  let(:suffix) { 'return' }

  let(:file_name) { 'hello.py' }
  let(:model_name) { 'codestral' }

  let(:unsafe_params) do
    {
      'current_file' => {
        'file_name' => file_name,
        'content_above_cursor' => prefix,
        'content_below_cursor' => suffix
      },
      'telemetry' => []
    }
  end

  let(:params) do
    {
      prefix: prefix,
      suffix: suffix,
      current_file: unsafe_params['current_file'].with_indifferent_access,
      model_name: model_name,
      model_endpoint: 'http://localhost:11434'
    }
  end

  before do
    allow(CodeSuggestions::ProgrammingLanguage).to receive(:detect_from_filename)
                                                     .with(file_name)
                                                     .and_return(language)
    allow(language).to receive(:name).and_return(language_name)
  end

  subject(:codestral_prompt) { described_class.new(params) }

  describe '#request_params' do
    let(:request_params) do
      {
        model_provider: described_class::MODEL_PROVIDER,
        model_name: model_name,
        prompt_version: prompt_version,
        model_endpoint: 'http://localhost:11434'
      }
    end

    let(:prompt) do
      <<~PROMPT.chomp
      <s>[SUFFIX]return[PREFIX]def hello_world():
      PROMPT
    end

    let(:expected_prompt) do
      prompt
    end

    context 'when instruction is not present' do
      it 'returns expected request params with final prompt' do
        expect(codestral_prompt.request_params).to eq(request_params.merge(prompt: expected_prompt))
      end
    end
  end
end
