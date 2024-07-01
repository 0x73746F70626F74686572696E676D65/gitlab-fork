# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Agents::SingleActionExecutor, feature_category: :duo_chat do
  describe "#execute" do
    subject(:answer) { agent.execute }

    let(:agent) do
      described_class.new(
        user_input: user_input,
        tools: tools,
        context: context,
        response_handler: response_service_double,
        stream_response_handler: stream_response_service_double
      )
    end

    let_it_be(:issue) { build_stubbed(:issue) }
    let_it_be(:resource) { issue }
    let_it_be(:user) { issue.author }

    let(:user_input) { 'question?' }
    let(:tools) { [Gitlab::Llm::Chain::Tools::IssueReader] }
    let(:tool_double) { instance_double(Gitlab::Llm::Chain::Tools::IssueReader::Executor) }
    let(:response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }
    let(:stream_response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }

    let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }

    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user, container: nil, resource: resource, ai_request: ai_request_double,
        extra_resource: nil, current_file: nil, agent_version: nil
      )
    end

    let(:answer_chunk) do
      "{\"type\":\"final_answer_delta\",\"data\":{\"thought\":\"Thought: direct answer.\",\"text\":\"Ans\"}}"
    end

    before do
      allow(context).to receive(:ai_request).and_return(ai_request_double)
      allow(ai_request_double).to receive(:request).and_return(answer_chunk)
    end

    context "when answer is final" do
      let(:another_chunk) do
        "{\"type\":\"final_answer_delta\",\"data\":{\"thought\":\"\",\"text\":\"wer\"}}"
      end

      let(:response_double) do
        "#{answer_chunk}\n#{another_chunk}"
      end

      let(:first_response_double) { double }
      let(:second_response_double) { double }

      before do
        allow(ai_request_double).to receive(:request).and_yield(answer_chunk)
                                                     .and_yield(another_chunk)
                                                     .and_return(response_double)
        allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with("Ans", { chunk_id: 1 })
                                                                            .and_return(first_response_double)
        allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with("wer", { chunk_id: 2 })
                                                                            .and_return(second_response_double)

        allow(context).to receive(:current_page_type).and_return("issue")
        allow(context).to receive(:current_page_short_description).and_return("issue description")
      end

      it "streams final answer" do
        expect(stream_response_service_double).to receive(:execute).with(
          response: first_response_double,
          options: { chunk_id: 1 }
        )
        expect(stream_response_service_double).to receive(:execute).with(
          response: second_response_double,
          options: { chunk_id: 2 }
        )

        expect(ai_request_double).to receive(:request).with(
          {
            prompt: user_input,
            options: {
              agent_scratchpad: [],
              conversation: [],
              single_action_agent: true,
              current_resource_type: "issue",
              current_resource_content: "issue description"
            }
          },
          { unit_primitive: nil }
        )

        expect(answer.is_final?).to be_truthy
        expect(answer.content).to include("Answer")
      end
    end

    context "when tool answer if final" do
      let(:llm_answer) { create(:answer, :tool, tool: Gitlab::Llm::Chain::Tools::IssueReader::Executor) }
      let(:tool_answer) { create(:answer, :final, content: 'tool answer') }

      before do
        allow(::Gitlab::Llm::Chain::Answer).to receive(:from_response).and_return(llm_answer)

        allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
          allow(issue_tool).to receive(:execute).and_return(tool_answer)
        end
      end

      it "returns tool answer" do
        expect(stream_response_service_double).to receive(:execute)
        expect(answer.is_final?).to be_truthy
        expect(answer.content).to include("tool answer")
      end
    end

    context "when max iteration reached" do
      let(:llm_answer) { create(:answer, :tool, tool: Gitlab::Llm::Chain::Tools::IssueReader::Executor) }

      before do
        stub_const("#{described_class.name}::MAX_ITERATIONS", 2)
        allow(stream_response_service_double).to receive(:execute)
        allow(::Gitlab::Llm::Chain::Answer).to receive(:from_response).and_return(llm_answer)

        allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
          allow(issue_tool).to receive(:execute).and_return(llm_answer)
        end
      end

      it "returns default answer" do
        expect(answer.is_final?).to eq(true)
        expect(answer.content).to include(Gitlab::Llm::Chain::Answer.default_final_message)
      end
    end

    context "when resource is not authorized" do
      let(:resource) { user }

      it "sends request without context" do
        expect(ai_request_double).to receive(:request).with(
          {
            prompt: user_input,
            options: {
              agent_scratchpad: [],
              conversation: [],
              single_action_agent: true,
              current_resource_type: nil,
              current_resource_content: nil
            }
          },
          { unit_primitive: nil }
        )

        agent.execute
      end
    end

    context "when times out error is raised" do
      let(:error) { Net::ReadTimeout.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      shared_examples "time out error" do
        it "returns an error" do
          expect(answer.is_final?).to eq(true)
          expect(answer.content).to include("I'm sorry, I couldn't respond in time. Please try again.")
          expect(answer.error_code).to include("A1000")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end
      end

      context "when streamed request times out" do
        before do
          allow(ai_request_double).to receive(:request).and_raise(error)
        end

        it_behaves_like "time out error"
      end

      context "when tool times out out" do
        let(:llm_answer) { create(:answer, :tool, tool: Gitlab::Llm::Chain::Tools::IssueReader::Executor) }

        before do
          allow(ai_request_double).to receive(:request)
          allow(::Gitlab::Llm::Chain::Answer).to receive(:from_response).and_return(llm_answer)
          allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueReader::Executor) do |issue_tool|
            allow(issue_tool).to receive(:execute).and_raise(error)
          end

          allow(stream_response_service_double).to receive(:execute)
        end

        it_behaves_like "time out error"
      end
    end

    context "when connection error is raised" do
      let(:error) { ::Gitlab::Llm::AiGateway::Client::ConnectionError.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        allow(ai_request_double).to receive(:request).and_raise(error)
      end

      it "returns an error" do
        expect(answer.is_final).to eq(true)
        expect(answer.content).to include("I'm sorry, I can't generate a response. Please try again.")
        expect(answer.error_code).to include("A1001")
        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
      end
    end
  end
end
