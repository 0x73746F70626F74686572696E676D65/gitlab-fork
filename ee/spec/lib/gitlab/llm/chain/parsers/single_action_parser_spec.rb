# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Parsers::SingleActionParser, feature_category: :duo_chat do
  describe "#parse" do
    let(:parser) { described_class.new(output: output) }
    let(:output) { chunks.map(&:to_json).join("\n") }

    before do
      parser.parse
    end

    context "with final answer" do
      let(:chunks) do
        [
          {
            type: "final_answer_delta",
            data: {
              thought: "Thought: I don't need any specific GitLab resources to answer this.",
              text: "To"
            }
          },
          { type: "final_answer_delta", data: { thought: "", text: " perform" } },
          { type: "final_answer_delta", data: { thought: "", text: " a" } },
          { type: "final_answer_delta", data: { thought: "", text: " Git" } },
          { type: "final_answer_delta", data: { thought: "", text: " re" } },
          { type: "final_answer_delta", data: { thought: "", text: "base" } },
          { type: "final_answer_delta", data: { thought: "", text: "," } }
        ]
      end

      it "returns only the final answer" do
        expect(parser.action).to be_nil
        expect(parser.action_input).to be_nil
        expect(parser.thought).to be_nil
        expect(parser.final_answer).to eq("To perform a Git rebase,")
      end
    end

    context "with chosen action" do
      let(:chunks) do
        [
          {
            type: "action",
            data: {
              thought: "Thought: I need to retrieve the issue details using the \"issue_reader\" tool.",
              tool: "issue_reader",
              tool_input: "What is the title of this issue?"
            }
          }
        ]
      end

      it "returns the action" do
        expect(parser.action).to eq("IssueReader")
        expect(parser.action_input).to eq("What is the title of this issue?")
        expect(parser.thought).to eq("Thought: I need to retrieve the issue details using the \"issue_reader\" tool.")
        expect(parser.final_answer).to be_nil
      end
    end

    context "with no output" do
      let(:output) { nil }

      it "returns nil" do
        expect(parser.action).to be_nil
        expect(parser.final_answer).to be_nil
      end
    end

    context "with empty output" do
      let(:output) { "" }

      it "returns nil" do
        expect(parser.action).to be_nil
        expect(parser.final_answer).to be_nil
      end
    end
  end
end
