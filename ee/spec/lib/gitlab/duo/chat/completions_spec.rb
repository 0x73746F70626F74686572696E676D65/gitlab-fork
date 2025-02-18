# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::Completions, feature_category: :duo_chat do
  let(:current_user) { create(:user) }
  let(:request_id) { 'uuid' }
  let(:content) { 'Explain this code' }
  let(:options) { {} }
  let(:completions_params) { { request_id: request_id, client_subscription_id: nil, content: content }.merge(options) }
  let(:referer_url) { 'http://127.0.0.1:3000/gitlab-org/gitlab-shell/-/blob/main/cmd/gitlab-shell/main.go?ref_type=heads' }
  let(:chat) { instance_double(Llm::Internal::CompletionService) }
  let(:blob) { instance_double(Gitlab::Git::Blob) }
  let(:chat_message) { instance_double(Gitlab::Llm::ChatMessage) }
  let(:resource) { current_user }
  let(:chat_message_params) do
    {
      request_id: request_id,
      content: content,
      role: ::Gitlab::Llm::AiMessage::ROLE_USER,
      ai_action: 'chat',
      user: current_user,
      context: an_object_having_attributes(resource: resource),
      client_subscription_id: nil
    }
  end

  subject(:chat_completions) do
    described_class.new(current_user, resource: resource).execute(safe_params: completions_params)
  end

  before do
    allow(SecureRandom).to receive(:uuid).and_return('uuid')
  end

  it 'saves question in the chat storage' do
    chat_completions

    expect(Gitlab::Llm::ChatStorage.new(current_user)
                                   .last_conversation
                                   .reverse.find { |message| message.role == 'user' }.content).to eq(content)
  end

  context 'with a referer URL' do
    let(:options) { { referer_url: referer_url } }
    let(:params) { { referer_url: referer_url, content: content } }

    it 'sends the referer URL to the chat' do
      expect(chat_message).to receive(:save!)
      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
      expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
      expect(chat).to receive(:execute)

      chat_completions
    end
  end

  context 'with an issue' do
    let_it_be(:issue) { create(:issue) }
    let(:resource) { issue }

    it 'sends resource to the chat' do
      expect(chat_message).to receive(:save!)
      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
      expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
      expect(chat).to receive(:execute)

      chat_completions
    end
  end

  context 'with an epic' do
    let(:epic) { create(:epic) }
    let(:resource) { epic }

    before do
      stub_licensed_features(epics: true)
    end

    it 'sends resource to the chat' do
      expect(chat_message).to receive(:save!)
      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
      expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
      expect(chat).to receive(:execute)

      chat_completions
    end
  end

  context 'with project' do
    let_it_be(:project) { create(:project) }
    let(:resource) { project }

    it 'sends resource to the chat' do
      expect(chat_message).to receive(:save!)
      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
      expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
      expect(chat).to receive(:execute)

      chat_completions
    end
  end

  context 'with group' do
    let_it_be(:group) { create(:group) }
    let(:resource) { group }

    it 'sends resource to the chat' do
      expect(chat_message).to receive(:save!)
      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
      expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
      expect(chat).to receive(:execute)

      chat_completions
    end
  end

  context 'without resource' do
    let(:params) { { content: content } }
    let(:resource) { current_user }

    it 'sends resource to the chat' do
      expect(chat_message).to receive(:save!)
      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
      expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
      expect(chat).to receive(:execute)

      chat_completions
    end
  end

  context 'with reset_history' do
    let(:completions_params) { { content: content, with_clean_history: true } }
    let(:resource) { current_user }
    let(:reset_message) { instance_double(Gitlab::Llm::ChatMessage) }

    it 'sends resource to the chat' do
      reset_params = chat_message_params.dup
      reset_params[:content] = '/reset'

      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(reset_params).twice.and_return(reset_message)
      expect(chat_message).to receive(:save!)
      expect(reset_message).to receive(:save!).twice
      expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
      expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
      expect(chat).to receive(:execute)

      chat_completions
    end
  end
end
