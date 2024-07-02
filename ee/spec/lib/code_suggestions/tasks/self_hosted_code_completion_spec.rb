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

  let(:self_hosted_model) { create(:ai_self_hosted_model, model: :codegemma, name: "whatever") }
  let(:feature_setting) do
    create(:ai_feature_setting, feature: :code_completions, self_hosted_model: self_hosted_model)
  end

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
      model_endpoint: feature_setting.self_hosted_model.endpoint,
      model_name: feature_setting.self_hosted_model.model
    }
  end

  let(:mistral_request_params) { { prompt_version: 2, prompt: 'Mistral prompt' } }

  let(:codgemma_messages_prompt) do
    instance_double(CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages,
      request_params: mistral_request_params)
  end

  subject(:task) do
    described_class.new(feature_setting: feature_setting,
      params: params, unsafe_passthrough_params: unsafe_params)
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

  describe 'prompt selection per model name' do
    let(:self_hosted_model) { create(:ai_self_hosted_model, model: model_name) }

    where(:model_name, :class_name) do
      [
        [:codegemma, CodeSuggestions::Prompts::CodeCompletion::CodeGemmaMessages],
        [:codestral, CodeSuggestions::Prompts::CodeCompletion::CodestralMessages]
      ]
    end

    with_them do
      it 'returns an instance of MistralMessages' do
        expect(
          class_name
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

  describe '#feature_name' do
    it 'returns code suggestions feature name' do
      expect(task.feature_name).to eq(:self_hosted_models)
    end
  end
end
