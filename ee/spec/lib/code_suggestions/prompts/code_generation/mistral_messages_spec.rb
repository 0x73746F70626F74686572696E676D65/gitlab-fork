# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::MistralMessages, feature_category: :custom_models do
  let(:prompt_version) { 3 }

  let(:language) { instance_double(CodeSuggestions::ProgrammingLanguage) }
  let(:language_name) { 'Ruby' }

  let(:examples) do
    [
      { 'example' => 'def greet',
        'response' => 'def greet puts "Hello, World!" end' }
    ]
  end

  let(:prefix) do
    <<~PREFIX
      class Greeter
    PREFIX
  end

  let(:suffix) do
    <<~SUFFIX
      end
    SUFFIX
  end

  let(:file_name) { 'hello.rb' }
  let(:model_name) { 'mistral' }
  let(:model_api_key) { 'model_api_key_123' }
  let(:comment) { 'Generate the best possible code based on instructions.' }
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
    allow(language).to receive(:generation_examples).with(type: instruction.trigger_type).and_return(examples)
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
        <s>[INST] You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Ruby code inside the file 'hello.rb'. Your task is to provide a valid replacement for [SUGGESTION] without any additional code, comments or explanation. Here are a few examples of successfully generated code:


          <s>[INST] def greet [/INST]
          def greet puts "Hello, World!" end
          </s>

        [/INST]</s>

        [INST]
        class Greeter

        [SUGGESTION]
        end

        [/INST]

        [INST]
        The new code you will generate will start at the position of the cursor, which is currently indicated by the [SUGGESTION] tag.
        In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
        likely new code to generate at the cursor position to fulfill the instructions.

        The comment directly before the cursor position is the instruction,
        all other comments are not instructions.

        When generating the new code, please ensure the following:
        1. It is valid Ruby code.
        2. It matches the existing code's variable, parameter and function names.
        3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
        4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
        5. The code fulfills in the instructions from the user in the comment just before the [SUGGESTION] position. All other comments are not instructions.
        6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

        If you are not able to write code based on the given instructions return an empty result.
        Don't return any text, just return the code results without extra explanation.
        [/INST]
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
