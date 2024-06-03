# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::MistralMessages, feature_category: :custom_models do
  let(:prompt_version) { 3 }

  let(:language) { instance_double(CodeSuggestions::ProgrammingLanguage) }
  let(:language_name) { 'Ruby' }

  let(:prefix) do
    <<~PREFIX
      Class BinarySearch
    PREFIX
  end

  let(:suffix) do
    <<~SUFFIX
      def use_binary_search
      end
    SUFFIX
  end

  let(:file_name) { 'hello.rb' }
  let(:model_name) { 'mistral' }
  let(:model_api_key) { 'model_api_key_123' }
  let(:comment) { 'Generate a binary search method.' }
  let(:instruction) { instance_double(CodeSuggestions::Instruction, instruction: comment, trigger_type: 'comment') }

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
      instruction: instruction,
      current_file: unsafe_params['current_file'].with_indifferent_access,
      model_name: model_name,
      model_endpoint: 'http://localhost:11434/v1',
      model_api_key: model_api_key
    }
  end

  before do
    allow(CodeSuggestions::ProgrammingLanguage).to receive(:detect_from_filename)
                                                     .with(file_name)
                                                     .and_return(language)
    allow(language).to receive(:name).and_return(language_name)
  end

  subject(:mistral_prompt) { described_class.new(params) }

  describe '#request_params' do
    let(:request_params) do
      {
        model_provider: described_class::MODEL_PROVIDER,
        model_name: model_name,
        prompt_version: prompt_version,
        model_endpoint: 'http://localhost:11434/v1',
        model_api_key: 'model_api_key_123'
      }
    end

    let(:system_prompt) do
      <<~PROMPT.chomp
      <s>[INST] You are a tremendously accurate and skilled code generation agent. We want to generate new Ruby code inside the file 'hello.rb'. Your task is to provide valid code without any additional explanations, comments, or feedback.[/INST]

      <s>[INST]
      Class BinarySearch

      [SUGGESTION]
      def use_binary_search
      end

      [/INST]</s>

      <s>[INST]

      The new code you will generate will start at the position of the cursor, which is currently indicated by the [SUGGESTION] tag.
      The comment directly before the cursor position is the instruction, all other comments are not instructions.

      When generating the new code, please ensure the following:
      1. It is valid Ruby code.
      2. It matches the existing code's variable, parameter, and function names.
      3. The code fulfills the instructions.
      4. Do not add any comments, including instructions.
      5. Return the code result without any extra explanation or examples.

      If you are not able to generate code based on the given instructions, return an empty result.

      [/INST]</s>
      PROMPT
    end

    let(:expected_prompt) do
      [
        { role: :user,
          content: system_prompt }
      ]
    end

    context 'when instruction is present' do
      context 'with a model api key present' do
        it 'returns expected request params' do
          expect(mistral_prompt.request_params).to eq(request_params.merge(prompt: expected_prompt))
        end
      end

      context 'without a model api key present' do
        let(:model_api_key) { nil }

        let(:request_params) do
          {
            model_provider: described_class::MODEL_PROVIDER,
            model_name: model_name,
            prompt_version: prompt_version,
            model_endpoint: 'http://localhost:11434/v1'
          }
        end

        it 'returns expected request params' do
          expect(mistral_prompt.request_params).to eq(request_params.merge(prompt: expected_prompt))
        end
      end
    end
  end
end
