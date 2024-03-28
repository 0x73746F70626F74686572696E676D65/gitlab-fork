# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::TaskFactory, feature_category: :code_suggestions do
  using RSpec::Parameterized::TableSyntax

  describe '.task' do
    let_it_be(:current_user) { create(:user) }
    let(:file_name) { 'python.py' }
    let(:prefix) { 'some prefix' }
    let(:suffix) { 'some suffix' }
    let(:params) do
      {
        current_file: {
          file_name: file_name,
          content_above_cursor: prefix,
          content_below_cursor: suffix
        },
        generation_type: 'empty_function'
      }
    end

    subject(:get_task) { described_class.new(current_user, params: params).task }

    shared_examples 'correct task initializer' do
      it 'creates task with correct params' do
        expect(expected_class).to receive(:new).with(**expected_params)

        get_task
      end
    end

    it 'calls instructions extractor with expected params' do
      expect(CodeSuggestions::InstructionsExtractor)
        .to receive(:new)
        .with(an_instance_of(CodeSuggestions::FileContent), nil, 'empty_function')
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
            model_name: described_class::ANTHROPIC_MODEL,
            current_user: current_user
          ),
          unsafe_passthrough_params: {}
        }
      end

      let(:instruction) do
        instance_double(CodeSuggestions::Instruction, instruction: 'instruction', trigger_type: 'comment')
      end

      before do
        allow_next_instance_of(CodeSuggestions::InstructionsExtractor) do |instance|
          allow(instance).to receive(:extract).and_return(instruction)
        end
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
    end
  end
end
