# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Completions::Chat, feature_category: :duo_chat do
  include FakeBlobHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository,  group: group) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:resource) { issue }
  let(:expected_container) { group }
  let(:content) { 'Summarize issue' }
  let(:ai_request) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:blob) { fake_blob(path: 'file.md') }
  let(:extra_resource) { { blob: blob } }
  let(:current_file) do
    {
      file_name: 'test.py',
      selected_text: 'selected',
      content_above_cursor: 'prefix',
      content_below_cursor: 'suffix'
    }
  end

  let(:options) { { content: content, extra_resource: extra_resource, current_file: current_file } }
  let(:container) { group }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      container: container,
      current_user: user,
      resource: resource,
      request_id: 'uuid',
      ai_request: ai_request,
      current_file: current_file
    )
  end

  let(:categorize_service) { instance_double(::Llm::ExecuteMethodService) }
  let(:categorize_service_params) { { question: content, request_id: 'uuid', message_id: prompt_message.id } }

  let(:answer) do
    ::Gitlab::Llm::Chain::Answer.new(
      status: :ok, context: context, content: content, tool: nil, is_final: true
    )
  end

  let(:response_handler) { instance_double(Gitlab::Llm::ResponseService) }
  let(:stream_response_handler) { nil }

  let(:prompt_message) do
    build(:ai_chat_message, user: user, resource: resource, request_id: 'uuid', content: content)
  end

  let(:tools) do
    [
      ::Gitlab::Llm::Chain::Tools::IssueIdentifier,
      ::Gitlab::Llm::Chain::Tools::JsonReader,
      ::Gitlab::Llm::Chain::Tools::GitlabDocumentation,
      ::Gitlab::Llm::Chain::Tools::EpicIdentifier,
      ::Gitlab::Llm::Chain::Tools::CiEditorAssistant
    ]
  end

  subject { described_class.new(prompt_message, nil, **options).execute }

  shared_examples 'success' do
    it 'calls the ZeroShot Agent with the right parameters', :snowplow do
      expected_params = [
        user_input: content,
        tools: match_array(tools),
        context: context,
        response_handler: response_handler,
        stream_response_handler: stream_response_handler
      ]

      expect_next_instance_of(::Gitlab::Llm::Chain::Agents::ZeroShot::Executor, *expected_params) do |instance|
        expect(instance).to receive(:execute).and_return(answer)
      end

      expect(response_handler).to receive(:execute)
      expect(::Gitlab::Llm::ResponseService).to receive(:new).with(context, { request_id: 'uuid', ai_action: :chat })
        .and_return(response_handler)
      expect(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
        .with(current_user: user, container: expected_container, resource: resource, ai_request: ai_request,
          extra_resource: extra_resource, request_id: 'uuid', current_file: current_file)
        .and_return(context)
      expect(categorize_service).to receive(:execute)
      expect(::Llm::ExecuteMethodService).to receive(:new)
        .with(user, user, :categorize_question, categorize_service_params)
        .and_return(categorize_service)

      subject

      expect_snowplow_event(
        category: described_class.to_s,
        label: "IssueIdentifier",
        action: 'process_gitlab_duo_question',
        property: 'uuid',
        namespace: container,
        user: user,
        value: 1
      )
    end

    context 'when client_subscription_id is set' do
      let(:prompt_message) do
        build(:ai_chat_message, user: user, resource: resource,
          request_id: 'uuid', client_subscription_id: 'someid', content: content)
      end

      let(:stream_response_handler) { instance_double(Gitlab::Llm::ResponseService) }

      it 'correctly initializes response handlers' do
        expected_params = [
          user_input: content,
          tools: an_instance_of(Array),
          context: an_instance_of(Gitlab::Llm::Chain::GitlabContext),
          response_handler: response_handler,
          stream_response_handler: stream_response_handler
        ]

        expect_next_instance_of(::Gitlab::Llm::Chain::Agents::ZeroShot::Executor, *expected_params) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end

        expect(response_handler).to receive(:execute)
        expect(::Gitlab::Llm::ResponseService).to receive(:new).with(
          an_instance_of(Gitlab::Llm::Chain::GitlabContext), { request_id: 'uuid', ai_action: :chat }
        ).and_return(response_handler)

        expect(::Gitlab::Llm::ResponseService).to receive(:new).with(
          an_instance_of(Gitlab::Llm::Chain::GitlabContext), { request_id: 'uuid', ai_action: :chat,
client_subscription_id: 'someid' }
        ).and_return(stream_response_handler)
        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new)
          .with(user, user, :categorize_question, categorize_service_params)
          .and_return(categorize_service)

        subject
      end
    end

    context 'with unsuccessful response' do
      let(:answer) do
        ::Gitlab::Llm::Chain::Answer.new(
          status: :error, context: context, content: content, tool: nil, is_final: true
        )
      end

      it 'sends process_gitlab_duo_question snowplow event with value eql 0' do
        allow_next_instance_of(::Gitlab::Llm::Chain::Agents::ZeroShot::Executor) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end

        allow(::Gitlab::Llm::Chain::GitlabContext).to receive(:new).and_return(context)
        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new)
         .with(user, user, :categorize_question, categorize_service_params)
         .and_return(categorize_service)

        subject

        expect_snowplow_event(
          category: described_class.to_s,
          label: "IssueIdentifier",
          action: 'process_gitlab_duo_question',
          property: 'uuid',
          namespace: container,
          user: user,
          value: 0
        )
      end
    end
  end

  describe '#execute' do
    before do
      allow(Gitlab::Llm::Chain::Requests::Anthropic).to receive(:new).and_return(ai_request)
      allow(context).to receive(:tools_used).and_return([Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor])
    end

    context 'when resource is an issue' do
      it_behaves_like 'success'
    end

    context 'when resource is a user' do
      let(:container) { nil }
      let(:expected_container) { nil }
      let_it_be(:resource) { user }

      it_behaves_like 'success'
    end

    context 'when resource is nil' do
      let(:resource) { nil }
      let(:expected_container) { nil }

      it_behaves_like 'success'
    end

    shared_examples_for 'tool behind a feature flag' do
      it 'calls zero shot agent with selected tools' do
        expected_params = [
          user_input: content,
          tools: match_array(tools),
          context: context,
          response_handler: response_handler,
          stream_response_handler: stream_response_handler
        ]

        expect_next_instance_of(::Gitlab::Llm::Chain::Agents::ZeroShot::Executor, *expected_params) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end
        expect(response_handler).to receive(:execute)
        expect(::Gitlab::Llm::ResponseService).to receive(:new).with(context, { ai_action: :chat, request_id: 'uuid' })
          .and_return(response_handler)
        expect(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
          .with(current_user: user, container: expected_container, resource: resource,
            ai_request: ai_request, extra_resource: extra_resource, request_id: 'uuid',
            current_file: current_file)
          .and_return(context)
        expect(categorize_service).to receive(:execute)
        expect(Llm::ExecuteMethodService).to receive(:new)
          .with(user, user, :categorize_question, categorize_service_params)
          .and_return(categorize_service)

        subject
      end
    end

    context 'when ci_editor_assistant_tool flag is switched off' do
      before do
        stub_feature_flags(ci_editor_assistant_tool: false, slash_commands: true)
      end

      it_behaves_like 'tool behind a feature flag' do
        let(:tools) do
          [
            ::Gitlab::Llm::Chain::Tools::JsonReader,
            ::Gitlab::Llm::Chain::Tools::IssueIdentifier,
            ::Gitlab::Llm::Chain::Tools::GitlabDocumentation,
            ::Gitlab::Llm::Chain::Tools::EpicIdentifier
          ]
        end
      end
    end

    context 'when message is a slash command' do
      shared_examples_for 'slash command execution' do
        let(:executor) { instance_double(Gitlab::Llm::Chain::Tools::ExplainCode::Executor) }

        it 'calls directly a tool' do
          expected_params = {
            context: an_instance_of(::Gitlab::Llm::Chain::GitlabContext),
            options: { input: content },
            stream_response_handler: nil,
            command: an_instance_of(::Gitlab::Llm::Chain::SlashCommand)
          }

          expect(::Gitlab::Llm::Chain::Agents::ZeroShot::Executor).not_to receive(:new)
          expect(expected_tool)
            .to receive(:new).with(expected_params).and_return(executor)
          expect(executor).to receive(:perform).and_return(answer)

          subject
        end

        context 'when slash_commands flag is disabled' do
          before do
            stub_feature_flags(slash_commands: false)
          end

          it_behaves_like 'success' do
            let(:tools) do
              [
                ::Gitlab::Llm::Chain::Tools::JsonReader,
                ::Gitlab::Llm::Chain::Tools::IssueIdentifier,
                ::Gitlab::Llm::Chain::Tools::GitlabDocumentation,
                ::Gitlab::Llm::Chain::Tools::EpicIdentifier,
                ::Gitlab::Llm::Chain::Tools::CiEditorAssistant
              ]
            end
          end
        end
      end

      context 'when /explain is used' do
        let(:content) { '/explain something' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::ExplainCode::Executor }
        end
      end

      context 'when /tests is used' do
        let(:content) { '/tests something' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::WriteTests::Executor }
        end
      end

      context 'when /refactor is used' do
        let(:content) { '/refactor something' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::RefactorCode::Executor }
        end
      end

      context 'when slash command does not exist' do
        let(:content) { '/explain2 something' }

        it 'process the message with zero shot agent' do
          expect_next_instance_of(::Gitlab::Llm::Chain::Agents::ZeroShot::Executor) do |instance|
            expect(instance).to receive(:execute).and_return(answer)
          end
          expect(::Gitlab::Llm::Chain::Tools::ExplainCode::Executor).not_to receive(:new)

          subject
        end
      end
    end
  end
end
