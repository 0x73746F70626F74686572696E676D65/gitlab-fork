# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::CiEditorAssistant::Executor, feature_category: :pipeline_composition do
  let_it_be(:user) { create(:user) }

  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: nil, ai_request: ai_request_double
    )
  end

  subject(:tool) { described_class.new(context: context, options: { input: 'input' }) }

  describe '#name' do
    it 'returns the tool name' do
      expect(described_class::NAME).to eq('CiEditorAssistant')
    end
  end

  describe '#description' do
    it 'returns tool description' do
      desc = 'Useful tool when you need to provide suggestions regarding anything related to ".gitlab-ci.yml" file.'

      expect(described_class::DESCRIPTION).to include(desc)
    end
  end

  describe '#execute' do
    context 'when context is not authorized' do
      include_context 'with stubbed LLM authorizer', allowed: false

      it 'returns error answer' do
        allow(tool).to receive(:authorize).and_return(false)

        answer = tool.execute

        response = "I'm sorry, I can't generate a response. You might want to try again. " \
          "You could also be getting this error because the items you're asking about " \
          "either don't exist, you don't have access to them, or your session has expired."
        expect(answer.content).to eq(response)
        expect(answer.error_code).to eq("M3003")
      end
    end

    context 'when context is authorized' do
      include_context 'with stubbed LLM authorizer', allowed: true

      context 'when response is successful' do
        it 'returns success answer' do
          allow(tool).to receive(:request).and_return('response')

          expect(tool.execute.content).to eq('response')
        end
      end

      context 'when error is raised during a request' do
        it 'returns error answer' do
          allow(tool).to receive(:request).and_raise(StandardError)

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))
          answer = tool.execute

          expect(answer.content).to eq("I'm sorry, I can't generate a response. Please try again.")
          expect(answer.error_code).to include("M4002")
        end
      end
    end

    context 'when code tool was already used' do
      before do
        context.tools_used << described_class
      end

      it 'returns already used answer' do
        allow(tool).to receive(:request).and_return('response')

        expect(tool.execute.content).to eq('You already have the answer from CiEditorAssistant tool, read carefully.')
      end
    end
  end
end
