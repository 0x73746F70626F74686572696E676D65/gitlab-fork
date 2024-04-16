# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Agents::ZeroShot::Executor, :clean_gitlab_redis_chat, feature_category: :duo_chat do
  include FakeBlobHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:existing_agent_version) { create(:ai_agent_version) }

  let(:input) { 'foo' }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:tool_answer) { instance_double(Gitlab::Llm::Chain::Answer, is_final?: false, content: 'Bar', status: :ok) }
  let(:tool_double) { instance_double(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor) }
  let(:tools) { [Gitlab::Llm::Chain::Tools::IssueIdentifier] }
  let(:extra_resource) { {} }
  let(:response_double) { "I know the final answer\nFinal Answer: Hello World" }
  let(:resource) { user }
  let(:response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }
  let(:stream_response_service_double) { nil }
  let(:current_file) { nil }
  let(:agent_version) { nil }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: resource, ai_request: ai_request_double,
      extra_resource: extra_resource, current_file: current_file, agent_version: agent_version
    )
  end

  before do
    # This is normally derived from the AI Request class, but since we're using a double we have to mock that
    allow(agent).to receive(:provider_prompt_class)
      .and_return(::Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
  end

  subject(:agent) do
    described_class.new(
      user_input: input,
      tools: tools,
      context: context,
      response_handler: response_service_double,
      stream_response_handler: stream_response_service_double
    )
  end

  describe '#execute' do
    before do
      allow(context).to receive(:ai_request).and_return(ai_request_double)
      allow(ai_request_double).to receive(:request).and_yield("Final Answer:").and_yield("Hello").and_yield(" World")
        .and_return(response_double)

      allow(tool_double).to receive(:execute).and_return(tool_answer)
      allow_next_instance_of(Gitlab::Llm::Chain::Answer) do |answer|
        allow(answer).to receive(:tool).and_return(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor)
      end
      allow(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor)
        .to receive(:new)
              .with(context: context, options: anything, stream_response_handler: stream_response_service_double)
              .and_return(tool_double)
    end

    it 'executes associated tools and adds observations during the execution' do
      answer = agent.execute

      expect(answer.is_final).to eq(true)
      expect(answer.content).to include('Hello World')
    end

    context 'without final answer' do
      let(:logger) { instance_double(Gitlab::Llm::Logger) }

      before do
        # just limiting the number of iterations here from 10 to 2
        stub_const("#{described_class.name}::MAX_ITERATIONS", 2)
        allow(agent).to receive(:logger).at_least(:once).and_return(logger)
        allow(agent).to receive(:request).and_return("Action: IssueIdentifier\nAction Input: #3")
      end

      it 'executes associated tools and adds observations during the execution' do
        expect(logger).to receive(:info).with(hash_including(message: 'Picked tool')).twice
        expect(response_service_double).to receive(:execute).at_least(:once)

        agent.execute
      end
    end

    context 'when max iterations reached' do
      it 'returns' do
        stub_const("#{described_class.name}::MAX_ITERATIONS", 2)

        allow(agent).to receive(:request).and_return("Action: IssueIdentifier\nAction Input: #3")
        expect(agent).to receive(:request).twice.times
        expect(response_service_double).to receive(:execute).at_least(:once)

        answer = agent.execute

        expect(answer.is_final?).to eq(true)
        expect(answer.content).to include(Gitlab::Llm::Chain::Answer.default_final_message)
      end
    end

    context 'when answer is final' do
      let(:response_content_1) { "Thought: I know final answer\nFinal Answer: Foo" }

      it 'returns final answer' do
        answer = agent.execute

        expect(answer.is_final?).to eq(true)
      end
    end

    context 'when tool answer if final' do
      let(:tool_answer) { instance_double(Gitlab::Llm::Chain::Answer, is_final?: true) }

      it 'returns final answer' do
        answer = agent.execute

        expect(answer.is_final?).to eq(true)
      end
    end

    context 'when stream_response_service is set' do
      let(:stream_response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }

      it 'streams the final answer' do
        first_response_double = double
        second_response_double = double

        allow(Gitlab::Llm::Chain::PlainResponseModifier).to receive(:new).with("Hello")
          .and_return(first_response_double)

        allow(Gitlab::Llm::Chain::PlainResponseModifier).to receive(:new).with(" World")
          .and_return(second_response_double)

        expect(stream_response_service_double).to receive(:execute).with(
          response: first_response_double,
          options: { chunk_id: 1 }
        )
        expect(stream_response_service_double).to receive(:execute).with(
          response: second_response_double,
          options: { chunk_id: 2 }
        )

        agent.execute
      end

      it 'streams the current tool', :aggregate_failures do
        tool_double = double

        allow(Gitlab::Llm::Chain::ToolResponseModifier).to receive(:new)
          .with(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor)
          .and_return(tool_double)

        expect(response_service_double).to receive(:execute).at_least(:once)
        expect(stream_response_service_double).to receive(:execute).at_least(:once).with(
          response: tool_double,
          options: { role: ::Gitlab::Llm::ChatMessage::ROLE_SYSTEM, type: 'tool' }
        )

        allow(agent).to receive(:request).and_return("Action: IssueIdentifier\nAction Input: #3")

        agent.execute
      end
    end
  end

  describe '#prompt' do
    let(:tools) do
      [
        Gitlab::Llm::Chain::Tools::IssueIdentifier,
        Gitlab::Llm::Chain::Tools::EpicIdentifier
      ]
    end

    let(:prompt_options) do
      {
        prompt_version: described_class::PROMPT_TEMPLATE,
        resources: 'issues, epics',
        system_prompt: nil
      }
    end

    before do
      allow(agent).to receive(:provider_prompt_class)
                        .and_return(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)

      create(:ai_chat_message, user: user, request_id: 'uuid1', role: 'user', content: 'question 1')
      create(:ai_chat_message, user: user, request_id: 'uuid1', role: 'assistant', content: 'response 1')
      # this should be ignored because response contains an error
      create(:ai_chat_message, user: user, request_id: 'uuid2', role: 'user', content: 'question 2')
      create(:ai_chat_message,
        user: user, request_id: 'uuid2', role: 'assistant', content: 'response 2', errors: ['error'])

      # this should be ignored because it doesn't contain response
      create(:ai_chat_message, user: user, request_id: 'uuid3', role: 'user', content: 'question 3')

      travel(2.minutes) do
        create(:ai_chat_message, user: user, request_id: 'uuid4', role: 'user', content: 'question 4')
      end
      travel(2.minutes) do
        create(:ai_chat_message, user: user, request_id: 'uuid5', role: 'user', content: 'question 5')
      end
      travel(3.minutes) do
        create(:ai_chat_message, user: user, request_id: 'uuid4', role: 'assistant', content: 'response 4')
      end
      travel(4.minutes) do
        create(:ai_chat_message, user: user, request_id: 'uuid5', role: 'assistant', content: 'response 5')
      end
    end

    it 'includes cleaned chat in prompt options with responses reordered to be paired with questions' do
      expected_chat = [
        an_object_having_attributes(content: 'question 1'),
        an_object_having_attributes(content: 'response 1'),
        an_object_having_attributes(content: 'question 4'),
        an_object_having_attributes(content: 'response 4'),
        an_object_having_attributes(content: 'question 5'),
        an_object_having_attributes(content: 'response 5')
      ]
      expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
        .to receive(:prompt).once.with(a_hash_including(conversation: expected_chat))

      agent.prompt
    end

    it 'includes the prompt options' do
      expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
        .to receive(:prompt).once.with(a_hash_including(prompt_options))

      agent.prompt
    end

    context 'when Claude 3 feature flag is enabled' do
      let(:prompt_options) { { zero_shot_prompt: described_class::CLAUDE_3_ZERO_SHOT_PROMPT } }

      it 'includes specific prompt for Claude 3 in the options' do
        expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
          .to receive(:prompt).once.with(a_hash_including(prompt_options))

        agent.prompt
      end
    end

    context 'when Claude 3 feature flag is disabled' do
      let(:prompt_options) { { zero_shot_prompt: described_class::ZERO_SHOT_PROMPT } }

      before do
        stub_feature_flags(ai_claude_3_sonnet: false)
      end

      it 'includes general prompt in the options' do
        expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
          .to receive(:prompt).once.with(a_hash_including(prompt_options))

        agent.prompt
      end
    end

    context 'when agent_version is passed' do
      let(:agent_version) { existing_agent_version }

      before do
        create(:ai_chat_message, user: user, agent_version_id: agent_version.id, request_id: 'uuid6', role: 'user',
          content: 'agent version message 1')
        create(:ai_chat_message, user: user, agent_version_id: agent_version.id, request_id: 'uuid6',
          role: 'assistant', content: 'agent version message 2')
      end

      it 'includes system prompt in prompt options' do
        expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
          .to receive(:prompt).once.with(a_hash_including({ system_prompt: existing_agent_version.prompt,
prompt_version: described_class::CUSTOM_AGENT_PROMPT_TEMPLATE }))

        agent.prompt
      end

      it 'includes only cleaned chat with messages for the user and agent' do
        expected_chat = [
          an_object_having_attributes(content: 'agent version message 1'),
          an_object_having_attributes(content: 'agent version message 2')
        ]
        expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
          .to receive(:prompt).once.with(a_hash_including(conversation: expected_chat))

        agent.prompt
      end
    end

    context 'when duo chat context is created' do
      shared_examples_for 'includes metadata' do
        let(:metadata) do
          <<~XML
            <root>
              <id>1</id>
              <iid>1</iid>
              <description>
                <title>My title 1</title>
              </description>
            </root>
          XML
        end

        let(:prompt_resource) do
          <<~CONTEXT
            <resource>
            #{metadata}
            </resource>
          CONTEXT
        end

        context "with claude 2" do
          before do
            stub_feature_flags(ai_claude_3_sonnet: false)
          end

          it 'includes the current resource metadata' do
            expect(context).to receive(:resource_serialized).and_return(metadata)
            expect(agent.prompt[:prompt]).to include(prompt_resource)
          end
        end

        context "with claude 3" do
          it 'includes the current resource metadata' do
            expect(context).to receive(:resource_serialized).and_return(metadata)
            expect(claude_3_system_prompt(agent)).to include(prompt_resource)
          end
        end
      end

      context 'when the resource is an issue' do
        let(:resource) { create(:issue) }

        it_behaves_like 'includes metadata'
      end

      context 'when the resource is an epic' do
        let(:resource) { create(:epic) }

        it_behaves_like 'includes metadata'
      end
    end

    context 'with self discover part' do
      let_it_be(:self_discoverability_prompt) { "You have access to the following GitLab resources: issues, epics" }

      context 'with claude 2.1' do
        before do
          stub_feature_flags(ai_claude_3_sonnet: false)
        end

        it 'includes self-discoverability part in the prompt' do
          expect(agent.prompt[:prompt]).to include self_discoverability_prompt
        end
      end

      context 'with claude 3' do
        it 'includes self-discoverability part in the prompt' do
          expect(claude_3_system_prompt(agent)).to include(self_discoverability_prompt)
        end
      end
    end

    context 'when current_file is included in context' do
      let(:selected_text) { 'code selection' }
      let(:current_file) do
        {
          file_name: 'test.py',
          selected_text: selected_text,
          cotent_above_cursor: 'prefix',
          content_below_cursor: 'suffix'
        }
      end

      context 'with claude 2.1' do
        before do
          stub_feature_flags(ai_claude_3_sonnet: false)
        end

        it 'includes selected code in the prompt' do
          expect(agent.prompt[:prompt]).to include("code selection")
        end

        context 'when selected_text is empty' do
          let(:selected_text) { '' }

          it 'does not include selected code in the prompt' do
            expect(agent.prompt[:prompt]).not_to include("code selection")
          end
        end
      end

      context 'with claude 3' do
        it 'includes selected code in the prompt' do
          expect(claude_3_system_prompt(agent)).to include("code selection")
        end
      end

      context 'when selected_text is empty' do
        let(:selected_text) { '' }

        it 'does not include selected code in the prompt' do
          expect(claude_3_system_prompt(agent)).not_to include("code selection")
        end
      end
    end

    context 'when resource is a blob' do
      let(:project) { build(:project) }
      let(:blob) { fake_blob(path: 'foobar.rb', data: 'puts "hello world"') }
      let(:extra_resource) { { blob: blob } }

      context 'with claude 2.1' do
        before do
          stub_feature_flags(ai_claude_3_sonnet: false)
        end

        it 'includes the blob name and data in the prompt' do
          expect(agent.prompt[:prompt]).to include("foobar.rb")
          expect(agent.prompt[:prompt]).to include("puts \"hello world\"")
        end
      end

      context 'with claude 3' do
        it 'includes the blob name and data in the prompt' do
          expect(claude_3_system_prompt(agent)).to include("foobar.rb")
          expect(claude_3_system_prompt(agent)).to include("puts \"hello world\"")
        end
      end
    end

    context 'when times out error is raised' do
      let(:error) { Net::ReadTimeout.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      context 'when streamed request times out' do
        it 'returns an error' do
          allow(ai_request_double).to receive(:request).and_raise(error)

          answer = agent.execute

          expect(answer.is_final).to eq(true)
          expect(answer.content).to include("GitLab Duo didn't respond")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end
      end

      context 'when tool times out out' do
        it 'returns an error' do
          allow(ai_request_double).to receive(:request).and_return("Action: IssueIdentifier\nAction Input: #3")
          allow_next_instance_of(Gitlab::Llm::Chain::Answer) do |answer|
            allow(answer).to receive(:tool).and_return(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor)
          end

          allow_next_instance_of(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor) do |instance|
            allow(instance).to receive(:execute).and_raise(error)
          end

          allow(response_service_double).to receive(:execute)

          answer = agent.execute

          expect(answer.is_final).to eq(true)
          expect(answer.content).to include("GitLab Duo didn't respond")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end
      end
    end

    context 'when connection error is raised' do
      let(:error) { ::Gitlab::Llm::AiGateway::Client::ConnectionError.new }

      before do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      context 'when streamed request times out' do
        it 'returns an error' do
          allow(ai_request_double).to receive(:request).and_raise(error)

          answer = agent.execute

          expect(answer.is_final).to eq(true)
          expect(answer.content).to include("GitLab Duo could not connect to the AI provider")
          expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
        end
      end
    end
  end

  def claude_3_system_prompt(agent)
    agent.prompt[:prompt].reverse.find { |h| h[:role] == :system }[:content]
  end
end
