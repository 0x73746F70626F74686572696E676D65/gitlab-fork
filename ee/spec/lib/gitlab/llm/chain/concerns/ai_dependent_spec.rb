# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Concerns::AiDependent, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:options) { { suggestions: "", input: "" } }
  let(:ai_request) { ::Gitlab::Llm::Chain::Requests::Anthropic.new(user, unit_primitive: 'duo_chat') }
  let(:context) do
    ::Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user,
      container: double,
      resource: double,
      ai_request: ai_request
    )
  end

  let(:logger) { instance_double('Gitlab::Llm::Logger') }

  describe '#prompt' do
    it "returns prompt" do
      tool = ::Gitlab::Llm::Chain::Tools::IssueReader::Executor.new(context: context, options: options)

      expect(tool.class::PROVIDER_PROMPT_CLASSES[:anthropic]).to receive(:prompt).and_call_original

      tool.prompt
    end

    context 'when there are no provider prompt classes' do
      let(:dummy_tool_class) do
        Class.new(::Gitlab::Llm::Chain::Tools::Tool) do
          include ::Gitlab::Llm::Chain::Concerns::AiDependent

          def provider_prompt_class
            nil
          end
        end
      end

      it 'raises error' do
        tool = dummy_tool_class.new(context: context, options: {})

        expect { tool.prompt }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#request' do
    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:info_or_debug)
    end

    it 'passes prompt to the ai_client' do
      tool = ::Gitlab::Llm::Chain::Tools::IssueReader::Executor.new(context: context, options: options)

      expect(ai_request).to receive(:request).with(tool.prompt)

      tool.request
    end

    it 'passes blocks forward to the ai_client' do
      b = proc { "something" }
      tool = ::Gitlab::Llm::Chain::Tools::IssueReader::Executor.new(context: context, options: options)

      expect(ai_request).to receive(:request).with(tool.prompt, &b)

      tool.request(&b)
    end

    it 'logs the request' do
      tool = ::Gitlab::Llm::Chain::Tools::IssueReader::Executor.new(context: context, options: options)
      expected_prompt = tool.prompt[:prompt]

      tool.request

      expect(logger).to have_received(:info_or_debug).with(context.current_user, message: "Prompt",
        class: tool.class.to_s, prompt: expected_prompt)
    end
  end
end
