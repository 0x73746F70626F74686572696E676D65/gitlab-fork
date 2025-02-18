# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Chat, :saas, feature_category: :duo_chat do
  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:tokens) do
    {
      api: create(:personal_access_token, scopes: %w[api], user: authorized_user),
      read_api: create(:personal_access_token, scopes: %w[read_api], user: authorized_user),
      ai_features: create(:personal_access_token, scopes: %w[ai_features], user: authorized_user),
      unauthorized_user: create(:personal_access_token, scopes: %w[api], user: build(:user))
    }
  end

  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :repository,  group: group) }
  let_it_be(:issue) { create(:issue, project: project) }

  let(:current_user) { nil }
  let(:headers) { {} }
  let(:resource) { issue }
  let(:content) { 'what is this issue about' }
  let(:params) { { content: content, resource_type: resource.class.to_s.downcase, resource_id: resource.id } }

  before do
    group.add_member(authorized_user, :developer)
    stub_licensed_features(epics: true)
    allow(SecureRandom).to receive(:uuid).and_return('uuid')

    # Bypass actual requests of AI Gateway client
    allow_next_instance_of(Gitlab::CloudConnector::SelfIssuedToken) do |access_token|
      allow(access_token).to receive(:encoded).and_return(nil)
    end
  end

  shared_examples 'a response' do |case_name|
    it "returns #{case_name} response", :freeze_time, :aggregate_failures do
      post_api

      expect(response).to have_gitlab_http_status(result)

      expect(json_response).to include(**response_body)
    end
  end

  shared_examples 'an unauthorized response' do
    include_examples 'a response', 'unauthorized' do
      let(:result) { :unauthorized }
      let(:response_body) do
        { "message" => "401 Unauthorized" }
      end
    end
  end

  shared_examples 'a forbidden response' do
    include_examples 'a response', 'unauthorized' do
      let(:result) { :forbidden }
      let(:response_body) do
        { "message" => "403 Forbidden" }
      end
    end
  end

  shared_examples 'a not found response' do
    include_examples 'a response', 'not found' do
      let(:result) { :not_found }
      let(:response_body) do
        { "message" => "404 Not Found" }
      end
    end
  end

  shared_examples 'an endpoint authenticated with token' do |success_http_status = :created|
    let(:current_user) { nil }
    let(:access_token) { tokens[:api] }

    before do
      stub_feature_flags(access_rest_chat: true)
      headers["Authorization"] = "Bearer #{access_token.token}"

      post_api
    end

    context 'when using token with :api scope' do
      it { expect(response).to have_gitlab_http_status(success_http_status) }
    end

    context 'when using token with :ai_features scope' do
      let(:access_token) { tokens[:ai_features] }

      it { expect(response).to have_gitlab_http_status(success_http_status) }
    end

    context 'when using token with :read_api scope' do
      let(:access_token) { tokens[:read_api] }

      it { expect(response).to have_gitlab_http_status(:forbidden) }
    end

    context 'when using token with :read_api scope but for an user without access to the ai features' do
      let(:access_token) { tokens[:unauthorized_user] }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end
  end

  describe 'POST /chat/completions' do
    include_context 'with ai features enabled for group'

    subject(:post_api) { post api('/chat/completions', current_user), params: params, headers: headers }

    context 'when user is not logged in' do
      let(:current_user) { nil }

      include_examples 'an unauthorized response'

      context 'and access token is provided' do
        it_behaves_like 'an endpoint authenticated with token'
      end
    end

    context 'when user is logged in' do
      let(:current_user) { authorized_user }

      context 'when API feature flag is disabled' do
        before do
          stub_feature_flags(access_rest_chat: false)
        end

        include_examples 'a not found response'
      end

      context 'with access to chat', :freeze_time do
        let(:request_id) { 'uuid' }
        let(:completions_params) { { request_id: request_id, client_subscription_id: nil } }
        let(:referer_url) { 'http://127.0.0.1:3000/gitlab-org/gitlab-shell/-/blob/main/cmd/gitlab-shell/main.go?ref_type=heads' }
        let(:chat) { instance_double(Llm::Internal::CompletionService) }
        let(:resource_finder) { instance_double(::Llm::ExtraResourceFinder) }
        let(:blob) { instance_double(Gitlab::Git::Blob) }
        let(:options) { {} }
        let(:chat_message) { instance_double(Gitlab::Llm::ChatMessage) }
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

        it 'saves question in the chat storage' do
          post_api

          expect(Gitlab::Llm::ChatStorage.new(authorized_user)
                                         .last_conversation
                                         .reverse.find { |message| message.role == 'user' }.content).to eq(content)
        end

        context 'with a referer URL' do
          let(:content) { 'Explain this code' }
          let(:options) { { referer_url: referer_url } }
          let(:params) { { referer_url: referer_url, content: content } }
          let(:resource) { current_user }

          it 'sends the referer URL to the chat' do
            expect(chat_message).to receive(:save!)
            expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
            expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
            expect(chat).to receive(:execute)

            post_api
          end
        end

        context 'with an issue' do
          it 'sends resource to the chat' do
            expect(chat_message).to receive(:save!)
            expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
            expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
            expect(chat).to receive(:execute)

            post_api
          end
        end

        context 'with an epic' do
          let(:epic) { create(:epic, group: group) }
          let(:resource) { epic }

          before do
            stub_licensed_features(epics: true)
          end

          it 'sends resource to the chat' do
            expect(chat_message).to receive(:save!)
            expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
            expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
            expect(chat).to receive(:execute)

            post_api
          end
        end

        context 'with project' do
          let(:resource) { project }

          it 'sends resource to the chat' do
            expect(chat_message).to receive(:save!)
            expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
            expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
            expect(chat).to receive(:execute)

            post_api
          end
        end

        context 'with group' do
          let(:resource) { group }

          it 'sends resource to the chat' do
            expect(chat_message).to receive(:save!)
            expect(Gitlab::Llm::ChatMessage).to receive(:new).with(chat_message_params).and_return(chat_message)
            expect(Llm::Internal::CompletionService).to receive(:new).with(chat_message, options).and_return(chat)
            expect(chat).to receive(:execute)

            post_api
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

            post_api
          end
        end

        context 'with reset_history' do
          let(:params) { { content: content, with_clean_history: true } }
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

            post_api
          end
        end
      end
    end
  end
end
