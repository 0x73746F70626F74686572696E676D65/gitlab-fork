# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Llm::Chain::Answers::StreamedJson, feature_category: :duo_chat do
  describe "#next_chunk" do
    subject { described_class.new.next_chunk(chunk) }

    context "when stream is empty" do
      let(:chunk) { "" }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    context "when stream does not contain the final answer" do
      let(:chunk) do
        {
          type: "action",
          data: {
            thought: "Thought: I need to retrieve the issue content using the \"issue_reader\" tool.",
            tool: "issue_reader",
            tool_input: "what is the title of this issue"
          }
        }.to_json
      end

      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    context "when streaming beginning of the answer" do
      let(:chunk) do
        {
          type: "final_answer_delta",
          data: {
            thought: "Thought: I should provide a direct response.",
            text: "I"
          }
        }.to_json
      end

      it 'returns stream payload' do
        is_expected.to eq({ id: 1, content: "I" })
      end
    end
  end
end
