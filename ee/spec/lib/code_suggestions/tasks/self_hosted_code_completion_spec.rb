# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::SelfHostedCodeCompletion, feature_category: :custom_models do
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

  let(:code_completions_feature_setting) { create(:ai_feature_setting, feature: :code_completions) }

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
      model_endpoint: code_completions_feature_setting.self_hosted_model.endpoint,
      model_name: code_completions_feature_setting.self_hosted_model.model
    }
  end

  let(:mistral_request_params) { { prompt_version: 2, prompt: 'Mistral prompt' } }

  let(:codgemma_messages_prompt) do
    instance_double(CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages,
      request_params: mistral_request_params)
  end

  subject(:task) do
    described_class.new(feature_setting: code_completions_feature_setting, params: params,
      unsafe_passthrough_params: unsafe_params)
  end

  describe '#body' do
    before do
      allow(CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages)
        .to receive(:new).and_return(codgemma_messages_prompt)
      stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    end

    context 'with codegemma:2b model' do
      it_behaves_like 'code suggestion task' do
        let(:endpoint_path) { 'v2/code/completions' }
        let(:body) { unsafe_params.merge(mistral_request_params.merge(expected_current_file)) }
      end

      it 'calls codegemma:2b' do
        task.body

        expect(CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages).to have_received(:new).with(params)
      end
    end
  end

  describe '#prompt' do
    before do
      allow(CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages)
        .to receive(:new).and_return(codgemma_messages_prompt)
      stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    end

    it 'returns message based prompt' do
      task.body

      expect(CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages).to have_received(:new).with(params)
    end
  end
end
