# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat', :js, :saas, :clean_gitlab_redis_cache, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  before do
    stub_feature_flags(duo_chat_requires_licensed_seat: false)
    group.add_developer(user)
    stub_application_setting(anthropic_api_key: 'somekey')
  end

  context 'when group does not have an AI features license' do
    let_it_be_with_reload(:group) { create(:group_with_plan) }

    before do
      sign_in(user)
      visit root_path
    end

    it 'does not show the button to open chat' do
      expect(page).not_to have_button('GitLab Duo Chat')
    end
  end

  context 'when group has an AI features license', :sidekiq_inline do
    include_context 'with duo features enabled and ai chat available for group on SaaS'

    let_it_be_with_reload(:group) { create(:group_with_plan, plan: :premium_plan) }

    let(:question) { 'Who are you?' }
    let(:answer) { 'I am GitLab Duo Chat' }
    let(:chat_response) { "Final Answer: #{answer}" }

    before do
      # TODO: remove with https://gitlab.com/gitlab-org/gitlab/-/issues/456258
      stub_feature_flags(v2_chat_agent_integration: false)

      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/chat/agent")
        .with(body: hash_including({ "stream" => true }))
        .to_return(status: 200, body: chat_response)

      sign_in(user)

      visit root_path
    end

    it 'returns response after asking a question', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/462444' do
      open_chat
      chat_request(question)

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(answer)
      end
    end

    it 'stores the chat history', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/462445' do
      open_chat
      chat_request(question)

      page.refresh
      open_chat

      within_testid('chat-component') do
        expect(page).to have_content(question)
        expect(page).to have_content(answer)
      end
    end

    it 'syncs the chat on a second tab', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/462446' do
      second_window = page.open_new_window

      within_window second_window do
        visit root_path
        open_chat
      end

      open_chat
      chat_request(question)

      within_window second_window do
        within_testid('chat-component') do
          expect(page).to have_content(question)
          expect(page).to have_content(answer)
        end
      end
    end
  end

  def open_chat
    click_button "GitLab Duo Chat"
  end

  def chat_request(question)
    fill_in 'GitLab Duo Chat', with: question
    send_keys :enter
    wait_for_requests
  end
end
