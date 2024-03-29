# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::ExplainCode::Executor, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:input) { 'input' }
  let(:options) { { input: input } }
  let(:stream_response_handler) { nil }
  let(:command) { nil }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: nil, ai_request: ai_request_double,
      current_file: {
        file_name: 'test.py',
        selected_text: 'selected text',
        content_above_cursor: 'code above',
        content_below_cursor: 'code below'
      }
    )
  end

  subject(:tool) do
    described_class.new(
      context: context, options: options, stream_response_handler: stream_response_handler, command: command
    )
  end

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('ExplainCode')
    end

    it 'returns tool human name' do
      expect(described_class::HUMAN_NAME).to eq('Explain Code')
    end
  end

  describe '#description' do
    it 'returns tool description' do
      desc = 'Useful tool to explain code snippets and blocks.'

      expect(described_class::DESCRIPTION).to include(desc)
    end
  end

  describe '#execute' do
    context 'when context is authorized' do
      include_context 'with stubbed LLM authorizer', allowed: true

      it_behaves_like 'slash command tool' do
        let(:prompt_class) { Gitlab::Llm::Chain::Tools::ExplainCode::Prompts::Anthropic }
        let(:extra_params) { {} }
      end

      it 'builds the expected prompt' do
        allow(tool).to receive(:provider_prompt_class)
          .and_return(Gitlab::Llm::Chain::Tools::ExplainCode::Prompts::Anthropic)

        expected_prompt = <<~PROMPT.chomp


          Human: You are a software developer.
          You can explain code snippets.
          The code is written in Python and stored as test.py

          Here is the content of the file user is working with:
          <file>
            code aboveselected textcode below
          </file>

          Here is the code user selected:
          <selected_code>
            selected text
          </selected_code>

          input
          Any code blocks in response should be formatted in markdown.

          Assistant:
        PROMPT

        expect(tool.prompt[:prompt]).to eq(expected_prompt)
      end

      context 'when response is successful' do
        it 'returns success answer' do
          allow(tool).to receive(:request).and_return('response')

          expect(tool.execute.content).to eq('response')
        end
      end

      context 'when error is raised during a request' do
        it 'returns error answer' do
          allow(tool).to receive(:request).and_raise(StandardError)

          expect(tool.execute.content).to eq('Unexpected error')
        end
      end
    end

    context 'when context is not authorized' do
      include_context 'with stubbed LLM authorizer', allowed: false

      it 'returns error answer' do
        allow(tool).to receive(:authorize).and_return(false)

        expect(tool.execute.content)
          .to eq('I am sorry, I am unable to find what you are looking for.')
      end
    end

    context 'when code tool was already used' do
      before do
        context.tools_used << described_class
      end

      it 'returns already used answer' do
        allow(tool).to receive(:request).and_return('response')

        expect(tool.execute.content).to eq('You already have the answer from ExplainCode tool, read carefully.')
      end
    end
  end
end
