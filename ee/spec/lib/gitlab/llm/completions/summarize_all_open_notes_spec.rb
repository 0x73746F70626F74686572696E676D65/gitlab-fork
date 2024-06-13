# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Completions::SummarizeAllOpenNotes, feature_category: :duo_chat do
  let(:template_class) { nil }
  let(:ai_response) { "some ai response text" }
  let(:client_subscription_id) { nil }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:prompt_message) do
    build(
      :ai_message, :summarize_comments, user: user, resource: issuable, request_id: 'uuid',
      client_subscription_id: client_subscription_id
    )
  end

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: issuable.resource_parent, resource: issuable, ai_request: ai_request_double
    )
  end

  RSpec.shared_examples 'performs completion' do
    it 'returns summary' do
      expect_next_instance_of(ai_request_class) do |instance|
        expect(instance).to receive(completion_method).and_return(ai_response)
      end

      response_modifier = double
      response_service = double
      params = [user, issuable, response_modifier, { options: { request_id: 'uuid', ai_action: :summarize_comments } }]

      content = "some ai response text"

      expect(Gitlab::Llm::ResponseModifiers::ToolAnswer).to receive(:new).with({ content: content }.to_json)
        .and_return(response_modifier)

      expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
        response_service
      )
      expect(response_service).to receive(:execute)

      summarize_comments
    end

    context 'with streamed response' do
      let(:client_subscription_id) { 'someid' }
      let(:answer) { ::Gitlab::Llm::Chain::Answer.final_answer(context: context, content: "ai response") }

      it 'calls the stream response service with the chunks' do
        allow(GraphqlTriggers).to receive(:ai_completion_response)
        expect(Gitlab::Llm::Chain::GitlabContext).to receive(:new).and_return(context)

        expect_next_instance_of(Gitlab::Llm::Chain::Tools::SummarizeComments::Executor) do |instance|
          expect(instance).to receive(:execute).and_yield("ai").and_yield("").and_yield(" response").and_return(answer)
        end

        summarize_comments

        expect(GraphqlTriggers).to have_received(:ai_completion_response).with(
          an_object_having_attributes(
            role: ::Gitlab::Llm::AiMessage::ROLE_ASSISTANT,
            request_id: 'uuid',
            user: user,
            content: 'ai',
            chunk_id: 1
          ))

        expect(GraphqlTriggers).to have_received(:ai_completion_response).with(
          an_object_having_attributes(
            role: ::Gitlab::Llm::AiMessage::ROLE_ASSISTANT,
            request_id: 'uuid',
            user: user,
            content: ' response',
            chunk_id: 2
          ))
      end
    end
  end

  RSpec.shared_examples 'completion fails' do
    it 'returns failure answer' do
      response_modifier = double
      response_service = double
      params = [user, issuable, response_modifier, { options: { request_id: 'uuid', ai_action: :summarize_comments } }]

      content = "I'm sorry, I can't generate a response. " \
        "The items you're asking about either don't exist, or you don't have access to them."

      expect(Gitlab::Llm::ResponseModifiers::ToolAnswer).to receive(:new).with(
        { content: content }.to_json
      ).and_return(
        response_modifier
      )

      expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).with(*params).and_return(
        response_service
      )
      expect(response_service).to receive(:execute)

      summarize_comments
    end
  end

  subject(:summarize_comments) do
    described_class.new(prompt_message, template_class, options).execute
  end

  describe "#execute", :saas do
    let(:ai_request_class) { ::Gitlab::Llm::Anthropic::Client }
    let(:completion_method) { :stream }
    let(:options) { {} }

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, group: group) }

    before_all do
      project.add_developer(user)
      group.add_developer(user)
    end

    before do
      allow(group.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
      stub_saas_features(gitlab_duo_saas_only: true)
      stub_licensed_features(
        summarize_comments: true,
        ai_features: true,
        epics: true,
        experimental_features: true,
        ai_chat: true
      )
      group.namespace_settings.update!(experiment_features_enabled: true)
      project.reload
    end

    context 'with invalid params' do
      context 'without issuable' do
        let_it_be(:issuable) { nil }

        specify { expect(summarize_comments).to be_nil }
      end
    end

    context 'with valid params' do
      context 'for an issue' do
        let_it_be(:issuable) { create(:issue, project: project) }
        let_it_be(:notes) { create_pair(:note_on_issue, project: project, noteable: issuable) }
        let_it_be(:system_note) { create(:note_on_issue, :system, project: project, noteable: issuable) }

        # anthropic as provider as summarize_notes_with_anthropic is enabled by default.
        it_behaves_like 'performs completion'

        context 'with vertex_ai provider' do
          let(:completion_method) { :text }
          let(:ai_request_class) { ::Gitlab::Llm::VertexAi::Client }
          let(:ai_response) { { "predictions" => [{ "content" => "some ai response text" }] } }

          before do
            stub_feature_flags(summarize_notes_with_anthropic: false)
          end

          it_behaves_like 'performs completion'
        end
      end

      context 'for a work item' do
        let_it_be(:issuable) { create(:work_item, :task, project: project) }
        let_it_be(:notes) { create_pair(:note_on_work_item, project: project, noteable: issuable) }
        let_it_be(:system_note) { create(:note_on_work_item, :system, project: project, noteable: issuable) }

        it_behaves_like 'performs completion'
      end

      context 'for a merge request' do
        let_it_be(:issuable) { create(:merge_request, source_project: project) }
        let_it_be(:notes) { create_pair(:note_on_merge_request, project: project, noteable: issuable) }
        let_it_be(:system_note) { create(:note_on_merge_request, :system, project: project, noteable: issuable) }

        #  summarize notes is not enabled for merge request, only for issues and epics.
        it_behaves_like 'completion fails'
      end

      context 'for an epic' do
        let_it_be(:issuable) { create(:epic, group: group) }
        let_it_be(:notes) { create_pair(:note_on_epic, noteable: issuable) }
        let_it_be(:system_note) { create(:note_on_epic, :system, noteable: issuable) }

        it_behaves_like 'performs completion'
      end
    end
  end
end
