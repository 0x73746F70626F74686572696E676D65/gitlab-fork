# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::ChatService, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:resource) { issue }
  let(:stage_check_available) { true }
  let(:content) { "Summarize issue" }
  let(:default_options) { { content: content } }
  let(:options) { default_options }

  shared_examples_for 'track internal event for Duo Chat' do
    it_behaves_like 'internal event tracking' do
      let(:event) { 'request_duo_chat_response' }
      let(:category) { described_class.name }

      subject(:track_event) { described_class.new(user, resource, options).execute }
    end

    it 'tracks AI metric', :click_house do
      stub_application_setting(use_clickhouse_for_analytics: true)

      expect(Gitlab::Tracking::AiTracking).to receive(:track_event)
                                                .with('request_duo_chat_response', user: user)
                                                .and_call_original

      described_class.new(user, resource, options).execute
    end
  end

  context 'for self-managed', :with_cloud_connector do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:agent) { create(:ai_agent, project: project) }
    let_it_be(:agent_version) { create(:ai_agent_version, agent: agent) }

    subject { described_class.new(user, resource, options) }

    context 'when ai features are enabled for instance' do
      include_context 'with duo features enabled and ai chat available for self-managed'

      before do
        allow(SecureRandom).to receive(:uuid).and_return('uuid')
      end

      context 'when user is part of the group' do
        before do
          group.add_developer(user)
        end

        context 'when resource is an issue' do
          let(:resource) { issue }
          let(:action_name) { :chat }
          let(:content) { 'Summarize issue' }

          it_behaves_like 'schedules completion worker'
          it_behaves_like 'llm service caches user request'
          it_behaves_like 'service emitting message for user prompt'
          it_behaves_like 'track internal event for Duo Chat' do
            let(:feature_enabled_by_namespace_ids) { [] }
          end
        end

        context 'when resource is a user' do
          let(:resource) { user }
          let(:action_name) { :chat }
          let(:content) { 'How to reset the password' }

          it_behaves_like 'schedules completion worker'
          it_behaves_like 'llm service caches user request'
          it_behaves_like 'service emitting message for user prompt'
          it_behaves_like 'track internal event for Duo Chat' do
            let(:project) { nil }
            let(:feature_enabled_by_namespace_ids) { [] }
          end
        end
      end

      context 'when user is not part of the group' do
        it 'returns an error' do
          expect(Llm::CompletionWorker).not_to receive(:perform_for)
          expect(subject.execute).to be_error
        end
      end

      context 'when an agent is passed' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?)
                              .with(user, :read_ai_agents, project)
                              .and_return(true)
        end

        let(:resource) { user }
        let(:options) { default_options.merge(agent_version_id: agent_version.to_gid) }
        let(:action_name) { :chat }

        it_behaves_like 'schedules completion worker' do
          let(:expected_options) { default_options.merge(agent_version_id: agent_version.id) }
        end

        it_behaves_like 'llm service caches user request'
        it_behaves_like 'service emitting message for user prompt'

        context 'when ai agent is not found' do
          let(:agent_version_id) { "gid://gitlab/Ai::AgentVersion/#{non_existing_record_id}" }
          let(:options) { default_options.merge(agent_version_id: GitlabSchema.parse_gid(agent_version_id)) }

          it 'returns an error' do
            expect(Llm::CompletionWorker).not_to receive(:perform_for)
            expect(subject.execute).to be_error
          end
        end

        context 'when user is not allowed to read the ai agent' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?)
                                .with(user, :read_ai_agents, project)
                                .and_return(false)
          end

          it 'is an invalid request' do
            expect(Llm::CompletionWorker).not_to receive(:perform_for)
            expect(subject.execute).to be_error
          end
        end
      end
    end

    context 'when ai features are disabled for instance' do
      include_context 'with duo features disabled and ai chat available for self-managed'

      it 'returns an error' do
        expect(Llm::CompletionWorker).not_to receive(:perform_for)
        expect(subject.execute).to be_error
      end
    end
  end

  context 'for saas', :saas do
    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:agent) { create(:ai_agent, project: project) }
    let_it_be(:agent_version) { create(:ai_agent_version, agent: agent) }

    subject { described_class.new(user, resource, options) }

    describe '#perform' do
      context 'when ai features are enabled for the group' do
        include_context 'with ai features enabled for group'

        before do
          allow(SecureRandom).to receive(:uuid).and_return('uuid')
          allow(Gitlab::Llm::StageCheck).to receive(:available?).with(group, :chat).and_return(stage_check_available)
        end

        context 'when user is part of the group' do
          before do
            group.add_developer(user)
          end

          context 'when resource is an issue' do
            let(:resource) { issue }
            let(:action_name) { :chat }
            let(:content) { 'Summarize issue' }

            it_behaves_like 'schedules completion worker'
            it_behaves_like 'llm service caches user request'
            it_behaves_like 'service emitting message for user prompt'
            it_behaves_like 'track internal event for Duo Chat' do
              let(:feature_enabled_by_namespace_ids) { [group.id] }
            end
          end

          context 'when resource is a user' do
            let(:resource) { user }
            let(:action_name) { :chat }
            let(:content) { 'How to reset the password' }

            it_behaves_like 'schedules completion worker'
            it_behaves_like 'llm service caches user request'
            it_behaves_like 'service emitting message for user prompt'
            it_behaves_like 'track internal event for Duo Chat' do
              let(:project) { nil }
              let(:feature_enabled_by_namespace_ids) { [group.id] }
            end
          end
        end

        context 'when user is not part of the group' do
          it 'returns an error' do
            expect(Llm::CompletionWorker).not_to receive(:perform_for)
            expect(subject.execute).to be_error
          end
        end

        context 'when an agent is passed' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?)
                                .with(user, :read_ai_agents, project)
                                .and_return(true)

            group.add_developer(user)
          end

          let(:resource) { user }
          let(:options) { default_options.merge(agent_version_id: agent_version.to_gid) }
          let(:action_name) { :chat }

          it_behaves_like 'schedules completion worker' do
            let(:expected_options) { default_options.merge(agent_version_id: agent_version.id) }
          end

          it_behaves_like 'llm service caches user request'
          it_behaves_like 'service emitting message for user prompt'

          context 'when ai agent is not found' do
            let(:agent_version_id) { "gid://gitlab/Ai::AgentVersion/#{non_existing_record_id}" }
            let(:options) { default_options.merge(agent_version_id: GitlabSchema.parse_gid(agent_version_id)) }

            it 'returns an error' do
              expect(Llm::CompletionWorker).not_to receive(:perform_for)
              expect(subject.execute).to be_error
            end
          end

          context 'when user is not allowed to read the ai agent' do
            before do
              allow(Ability).to receive(:allowed?).and_call_original
              allow(Ability).to receive(:allowed?)
                                  .with(user, :read_ai_agents, project)
                                  .and_return(false)
            end

            it 'is an invalid request' do
              expect(Llm::CompletionWorker).not_to receive(:perform_for)
              expect(subject.execute).to be_error
            end
          end
        end
      end
    end
  end
end
