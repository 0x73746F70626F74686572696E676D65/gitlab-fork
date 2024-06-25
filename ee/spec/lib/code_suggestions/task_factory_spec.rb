# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::TaskFactory, feature_category: :code_suggestions do
  using RSpec::Parameterized::TableSyntax

  describe '.task' do
    let_it_be(:current_user) { create(:user) }
    let(:file_name) { 'python.py' }
    let(:prefix) { 'some prefix' }
    let(:suffix) { 'some suffix' }
    let(:user_instruction) { nil }
    let(:params) do
      {
        current_file: {
          file_name: file_name,
          content_above_cursor: prefix,
          content_below_cursor: suffix
        },
        generation_type: 'empty_function',
        user_instruction: user_instruction,
        context: [
          { type: 'file', name: 'main.go', content: 'package main' }
        ]
      }
    end

    subject(:get_task) { described_class.new(current_user, params: params).task }

    shared_examples 'correct task initializer' do
      it 'creates task with correct params' do
        expect(expected_class).to receive(:new).with(**expected_params)

        get_task
      end
    end

    it 'calls context trimmer' do
      ctx = instance_double(CodeSuggestions::Context, :trimmed)
      expect(CodeSuggestions::Context).to receive(:new).with(params[:context]).and_return(ctx)
      expect(ctx).to receive(:trimmed)

      get_task
    end

    it 'calls instructions extractor with expected params' do
      expect(CodeSuggestions::InstructionsExtractor)
        .to receive(:new)
        .with(an_instance_of(CodeSuggestions::FileContent), nil, 'empty_function', user_instruction)
        .and_call_original

      get_task
    end

    context 'when code completion' do
      let(:expected_class) { ::CodeSuggestions::Tasks::CodeCompletion }
      let(:expected_project) { nil }
      let(:expected_params) do
        {
          params: params,
          unsafe_passthrough_params: {}
        }
      end

      before do
        allow_next_instance_of(CodeSuggestions::InstructionsExtractor) do |instance|
          allow(instance).to receive(:extract).and_return(nil)
        end
      end

      it_behaves_like 'correct task initializer'

      context 'when on a self managed instance' do
        let(:expected_class) { ::CodeSuggestions::Tasks::SelfHostedCodeCompletion }
        let(:expected_params) do
          {
            feature_setting: feature_setting,
            params: params,
            unsafe_passthrough_params: {}
          }
        end

        let(:feature_setting) { create(:ai_feature_setting, feature: :code_completions) }

        context 'when code completion is self-hosted' do
          it_behaves_like 'correct task initializer'
        end
      end
    end

    context 'when code generation' do
      let(:expected_class) { ::CodeSuggestions::Tasks::CodeGeneration }
      let(:expected_project) { nil }
      let(:expected_params) do
        {
          params: params.merge(
            instruction: instruction,
            prefix: prefix,
            project: expected_project,
            model_name: expected_model,
            current_user: current_user,
            skip_dependency_descriptions: true
          ),
          unsafe_passthrough_params: {}
        }
      end

      let(:instruction) do
        instance_double(CodeSuggestions::Instruction, instruction: 'instruction', trigger_type: 'comment')
      end

      let(:expected_model) { 'claude-3-sonnet-20240229' }

      before do
        allow_next_instance_of(CodeSuggestions::InstructionsExtractor) do |instance|
          allow(instance).to receive(:extract).and_return(instruction)
        end

        stub_feature_flags(claude_3_code_generation_haiku: false)
        stub_feature_flags(claude_3_5_code_generation_sonnet: false)
      end

      it_behaves_like 'correct task initializer'

      context 'with project' do
        let_it_be(:expected_project) { create(:project) }
        let(:params) do
          {
            current_file: {
              file_name: file_name,
              content_above_cursor: prefix,
              content_below_cursor: suffix
            },
            project_path: expected_project.full_path
          }
        end

        before do
          allow_next_instance_of(::ProjectsFinder) do |instance|
            allow(instance).to receive(:execute).and_return([expected_project])
          end
        end

        it 'fetches project' do
          get_task

          expect(::ProjectsFinder).to have_received(:new)
            .with(
              current_user: current_user,
              params: { full_paths: [expected_project.full_path] }
            )
        end
      end

      context 'with user_instruction param' do
        let(:user_instruction) { 'Some user instruction' }

        it_behaves_like 'correct task initializer'
      end

      context 'when on a self managed instance' do
        let(:expected_class) { ::CodeSuggestions::Tasks::SelfHostedCodeGeneration }
        let(:expected_params) do
          {
            feature_setting: feature_setting,
            params: params,
            unsafe_passthrough_params: {}
          }
        end

        let(:feature_setting) { create(:ai_feature_setting, feature: :code_generations) }

        context 'when code generations is self-hosted' do
          it_behaves_like 'correct task initializer'
        end
      end

      context 'with claude_3_code_generation_haiku flag is enabled' do
        before do
          stub_feature_flags(claude_3_code_generation_haiku: true)
        end

        let(:expected_model) { 'claude-3-haiku-20240307' }

        it_behaves_like 'correct task initializer'
      end

      context 'with claude_3_5_code_generation_sonnet flag is enabled' do
        before do
          stub_feature_flags(claude_3_5_code_generation_sonnet: true)
        end

        let(:expected_model) { 'claude-3-5-sonnet-20240620' }

        it_behaves_like 'correct task initializer'
      end

      context 'when code_suggestions_context feature flag is off' do
        let(:expected_params) do
          {
            params: params.except(:user_instruction, :context).merge(
              instruction: instruction,
              prefix: prefix,
              project: expected_project,
              model_name: described_class::ANTHROPIC_MODEL,
              current_user: current_user,
              skip_dependency_descriptions: true
            ),
            unsafe_passthrough_params: {}
          }
        end

        before do
          stub_feature_flags(code_suggestions_context: false)
        end

        it_behaves_like 'correct task initializer'
      end

      context 'when code_suggestions_skip_dependency_descriptions is off' do
        let(:expected_params) do
          {
            params: params.merge(
              instruction: instruction,
              prefix: prefix,
              project: expected_project,
              model_name: described_class::ANTHROPIC_MODEL,
              current_user: current_user,
              skip_dependency_descriptions: false
            ),
            unsafe_passthrough_params: {}
          }
        end

        before do
          stub_feature_flags(code_suggestions_skip_dependency_descriptions: false)
        end

        it_behaves_like 'correct task initializer'
      end
    end
  end
end
