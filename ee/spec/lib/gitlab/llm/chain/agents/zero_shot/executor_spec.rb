# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Agents::ZeroShot::Executor, :clean_gitlab_redis_chat, feature_category: :shared do
  let_it_be(:user) { create(:user) }

  let(:input) { 'foo' }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:tool_answer) { instance_double(Gitlab::Llm::Chain::Answer, is_final?: false, content: 'Bar', status: :ok) }
  let(:tool_double) { instance_double(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor) }
  let(:tools) { [Gitlab::Llm::Chain::Tools::IssueIdentifier] }
  let(:response_double) { "I know the final answer\nFinal Answer: FooBar" }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: user, ai_request: ai_request_double
    )
  end

  subject(:agent) { described_class.new(user_input: input, tools: tools, context: context) }

  describe '#execute' do
    before do
      allow(context).to receive(:ai_request).and_return(ai_request_double)
      allow(ai_request_double).to receive(:request).and_return(response_double)
      allow(tool_double).to receive(:execute).and_return(tool_answer)
      allow_next_instance_of(Gitlab::Llm::Chain::Answer) do |answer|
        allow(answer).to receive(:tool).and_return(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor)
      end
      allow(Gitlab::Llm::Chain::Tools::IssueIdentifier::Executor)
        .to receive(:new)
        .with(context: context, options: anything)
        .and_return(tool_double)
    end

    it 'executes associated tools and adds observations during the execution' do
      answer = agent.execute

      expect(answer.is_final).to eq(true)
      expect(answer.content).to include('FooBar')
    end

    context 'when max iterations reached' do
      it 'returns' do
        stub_const("#{described_class.name}::MAX_ITERATIONS", 2)

        allow(agent).to receive(:request).and_return("Action: IssueIdentifier\nAction Input: #3")
        expect(agent).to receive(:request).twice.times

        answer = agent.execute

        expect(answer.is_final?).to eq(true)
        expect(answer.content).to include(Gitlab::Llm::Chain::Answer.default_final_answer)
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
  end

  describe '#prompt' do
    before do
      allow(agent).to receive(:provider_prompt_class)
        .and_return(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)

      Gitlab::Llm::Cache.new(user).add(request_id: 'uuid1', role: 'user', content: 'question 1')
      Gitlab::Llm::Cache.new(user).add(request_id: 'uuid1', role: 'assistant', content: 'response 1')
      # this should be ignored because response contains an error
      Gitlab::Llm::Cache.new(user).add(request_id: 'uuid2', role: 'user', content: 'question 2')
      Gitlab::Llm::Cache.new(user)
        .add(request_id: 'uuid2', role: 'assistant', content: 'response 2', errors: ['error'])
      # this should be ignored because it doesn't contain response
      Gitlab::Llm::Cache.new(user).add(request_id: 'uuid3', role: 'user', content: 'question 3')
      Gitlab::Llm::Cache.new(user).add(request_id: 'uuid4', role: 'user', content: 'question 4')
      Gitlab::Llm::Cache.new(user).add(request_id: 'uuid4', role: 'assistant', content: 'response 4')
    end

    it 'includes cleaned chat in prompt options' do
      expected_chat = [
        an_object_having_attributes(content: 'question 1'),
        an_object_having_attributes(content: 'response 1'),
        an_object_having_attributes(content: 'question 4'),
        an_object_having_attributes(content: 'response 4')
      ]
      expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
        .to receive(:prompt).once.with(a_hash_including(conversation: expected_chat))

      agent.prompt
    end

    context 'when ai_chat_history_context is disabled' do
      before do
        stub_feature_flags(ai_chat_history_context: false)
      end

      it 'includes an ampty chat' do
        expect(Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic)
          .to receive(:prompt).once.with(a_hash_including(conversation: []))

        agent.prompt
      end
    end
  end

  describe 'real requests', :real_ai_request, :saas do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, group: group) }
    let(:resource) { user }

    let(:executor) do
      ai_request = ::Gitlab::Llm::Chain::Requests::Anthropic.new(user)
      context = ::Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: resource.try(:resource_parent)&.root_ancestor,
        resource: resource,
        ai_request: ai_request
      )

      described_class.new(
        user_input: input,
        tools: Gitlab::Llm::Completions::Chat::TOOLS,
        context: context
      )
    end

    before do
      stub_licensed_features(ai_features: true)
      stub_ee_application_setting(should_check_namespace_plan: true)
      group.add_owner(user)
      group.namespace_settings.update!(
        third_party_ai_features_enabled: true,
        experiment_features_enabled: true
      )
    end

    shared_examples_for 'successful prompt processing' do
      it 'answers query using expected tools', :aggregate_failures do
        answer = executor.execute

        expect(executor.prompt).to match_llm_tools(tools)
        expect(answer.content).to match_llm_answer(answer_match)
      end
    end

    context 'with predefined issue' do
      let_it_be(:label) { create(:label, project: project, title: 'ai-enablement') }
      let_it_be(:milestone) { create(:milestone, project: project, title: 'milestone1', due_date: 3.days.from_now) }
      let_it_be(:issue) do
        create(:issue, project: project, title: 'A testing issue for AI reliability',
          description: 'This issue is about evaluating reliability of various AI providers.',
          labels: [label], created_at: 2.days.ago, milestone: milestone)
      end

      # rubocop: disable Layout/LineLength
      where(:input_template, :tools, :answer_match) do
        'Can you list all labels on %{issue_identifier} issue?'                       | ['IssueIdentifier', 'Resource Reader'] | /ai-enablement/
        'How many days ago was %<issue_identifier>s issue created?'                   | ['IssueIdentifier', 'Resource Reader'] | /2 days/
        'For which milestone is %<issue_identifier>s issue? And how long until then?' | ['IssueIdentifier', 'Resource Reader'] | /milestone1.*3 days/
      end
      # rubocop: enable Layout/LineLength

      with_them do
        let(:input) { format(input_template, issue_identifier: issue.to_reference(full: true)) }

        it_behaves_like 'successful prompt processing'
      end

      context 'with chat history' do
        let_it_be(:issue2) do
          create(
            :issue,
            project: project,
            title: 'AI chat - send websocket subscription message also for user messages',
            description: 'To make sure that new messages are propagated to all chat windows ' \
                         '(e.g. if user has chat window open in multiple windows) we should send subscription ' \
                         'message for user messages too (currently we send messages only for AI responses)'
          )
        end

        let(:history) do
          [
            { role: 'user', content: "What is issue #{issue.to_reference(full: true)} about?" },
            { role: 'assistant', content: "The summary of issue is:\n\n## Provider Comparison\n" \
                                          "- Difficulty in evaluating which provider is better \n" \
                                          "- Both providers have pros and cons" }
          ]
        end

        before do
          uuid = SecureRandom.uuid

          history.each do |message|
            Gitlab::Llm::Cache.new(user).add({ request_id: uuid, role: message[:role], content: message[:content] })
          end
        end

        # rubocop: disable Layout/LineLength
        where(:input_template, :tools, :answer_match) do
          # evaluation of questions which involve processing of other resources is not reliable yet
          # because both IssueIdentifider and JsonReader tools assume we work with single resource:
          # IssueIdentifider overrides context.resource
          # JsonReader takes resource from context
          # So JsonReader twice with different action input
          # 'Is it duplicate of issue %<issue_identifier2>s issue?' | ['IssueIdentifier', 'Resource Reader'] | /no/i
          'Can you provide more details about that issue?' | ['IssueIdentifier', 'Resource Reader'] | /(reliability|providers)/
          # Translation would have to be explicitly allowed in protmp rules first
          # 'Can you translate your last answer to German?' | [] | /Anbieter/ # Anbieter == provider
          'Can you reword your answer?' | [] | /provider/i
        end
        # rubocop: enable Layout/LineLength

        with_them do
          let(:input) do
            format(input_template, issue_identifier: issue.to_reference(full: true),
              issue_identifier2: issue2.to_reference(full: true))
          end

          it_behaves_like 'successful prompt processing'
        end
      end
    end
  end
end
