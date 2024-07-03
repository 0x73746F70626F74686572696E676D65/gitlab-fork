# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Utils::ChatConversation, feature_category: :duo_chat do
  describe "#truncated_conversation_list" do
    subject(:conversation) { described_class.new(user).truncated_conversation_list }

    let(:user) { build_stubbed(:user) }

    before do
      allow(::Gitlab::Llm::ChatStorage).to receive(:last_conversation).and_return(messages)
    end

    context "with different messages" do
      let(:messages) do
        [
          build(:ai_chat_message, request_id: "uuid1", content: "question 1"),
          build(:ai_chat_message, request_id: "uuid2", content: "question 2"),
          build(:ai_chat_message, request_id: "uuid3", content: "question 3"),
          build(:ai_chat_message, request_id: "uuid4", content: "question 4"),
          build(:ai_chat_message, :assistant, request_id: "uuid3", errors: ["error"], content: "answer 3"),
          build(:ai_chat_message, :assistant, request_id: "uuid2", content: "answer 2"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: "answer 1")
        ]
      end

      let(:history) { conversation.pluck(:content) }

      it "returns only successful conversations in a right order" do
        expect(history).to contain_exactly("question 1", "answer 1", "question 2", "answer 2")
      end

      context "with limit on messages" do
        subject(:conversation) { described_class.new(user).truncated_conversation_list(last_n: 3) }

        it "returns exact number of messages" do
          expect(history).to contain_exactly("answer 1", "question 2", "answer 2")
        end
      end

      context "with more messages than default limit" do
        before do
          stub_const("#{described_class}::LAST_N_CONVERSATIONS", 3)
        end

        it "returns exact number of messages" do
          expect(history).to contain_exactly("answer 1", "question 2", "answer 2")
        end
      end
    end

    context "with empty history" do
      let(:messages) { [] }

      it "returns an empty conversation" do
        expect(conversation).to be_empty
      end
    end
  end
end
