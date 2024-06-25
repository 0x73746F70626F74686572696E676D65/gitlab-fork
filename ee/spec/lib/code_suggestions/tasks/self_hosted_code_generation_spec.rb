# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::SelfHostedCodeGeneration, feature_category: :custom_models do
  let(:prefix) { 'some prefix' }
  let(:suffix) { 'some suffix' }
  let(:instruction) { 'Add code for validating function' }

  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => prefix,
      'content_below_cursor' => suffix
    }.with_indifferent_access
  end

  let(:code_generations_feature_setting) { create(:ai_feature_setting, feature: :code_generations) }

  let(:expected_current_file) do
    { current_file: { file_name: 'test.py', content_above_cursor: 'fix', content_below_cursor: 'som' } }
  end

  let(:unsafe_params) do
    {
      'current_file' => current_file,
      'telemetry' => [],
      "stream" => false
    }.with_indifferent_access
  end

  let(:params) do
    {
      current_file: current_file,
      generation_type: 'empty_function',
      model_endpoint: code_generations_feature_setting.self_hosted_model.endpoint,
      model_name: code_generations_feature_setting.self_hosted_model.model,
      model_api_key: nil
    }
  end

  let(:expected_params) do
    {
      feature_setting: feature_setting,
      params: params,
      unsafe_passthrough_params: {}
    }
  end

  let(:mistral_request_params) { { prompt_version: 3, prompt: 'Mistral prompt' } }

  let(:mistral_messages_prompt) do
    instance_double(CodeSuggestions::Prompts::CodeGeneration::MistralMessages,
      request_params: mistral_request_params)
  end

  subject(:task) do
    described_class.new(feature_setting: code_generations_feature_setting, params: params,
      unsafe_passthrough_params: unsafe_params)
  end

  describe '#body' do
    before do
      allow(CodeSuggestions::Prompts::CodeGeneration::MistralMessages)
        .to receive(:new).and_return(mistral_messages_prompt)
      stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    end

    context 'with mistral model family' do
      it_behaves_like 'code suggestion task' do
        let(:endpoint_path) { 'v2/code/generations' }
        let(:body) { unsafe_params.merge(mistral_request_params.merge(expected_current_file)) }
      end

      it 'calls Mistral' do
        task.body

        expect(CodeSuggestions::Prompts::CodeGeneration::MistralMessages).to have_received(:new).with(params)
      end
    end

    context 'with a model api key present' do
      let(:params) do
        {
          current_file: current_file,
          generation_type: 'empty_function',
          model_endpoint: code_generations_feature_setting.self_hosted_model.endpoint,
          model_name: code_generations_feature_setting.self_hosted_model.model,
          model_api_key: 'api_token_123'
        }
      end

      before do
        code_generations_feature_setting.self_hosted_model.update!(api_token: 'api_token_123')
      end

      it 'calls Mistral with the api key' do
        task.body

        expect(CodeSuggestions::Prompts::CodeGeneration::MistralMessages).to have_received(:new).with(params)
      end
    end
  end

  describe '#prompt' do
    before do
      allow(CodeSuggestions::Prompts::CodeGeneration::MistralMessages)
        .to receive(:new).and_return(mistral_messages_prompt)
      stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    end

    it 'returns message based prompt' do
      task.body

      expect(CodeSuggestions::Prompts::CodeGeneration::MistralMessages).to have_received(:new).with(params)
    end
  end

  describe 'prompt selection per model name' do
    let(:self_hosted_model) { create(:ai_self_hosted_model, model: model_name) }
    let(:code_generations_feature_setting) { create(:ai_feature_setting, self_hosted_model: self_hosted_model) }

    where(:model_name) do
      %w[codestral codegemma mistral mixtral]
    end

    with_them do
      it 'returns an instance of MistralMessages' do
        expect(
          CodeSuggestions::Prompts::CodeGeneration::MistralMessages
        ).to receive(:new).with(any_args).and_call_original

        task.body
      end
    end

    context 'when model name is unknown' do
      let(:self_hosted_model) { create(:ai_self_hosted_model) }

      it 'raises an error' do
        allow(self_hosted_model).to receive(:model).and_return('unknown')

        expect { task.body }.to raise_error("Unknown model: unknown")
      end
    end
  end
end
