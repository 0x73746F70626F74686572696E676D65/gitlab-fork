# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::Llm::GitCommand, :saas, feature_category: :source_code_management do
  let_it_be(:current_user) { create :user }

  let(:header) { { 'Authorization' => ['Bearer test-key'], 'Content-Type' => ['application/json'] } }
  let(:url) { '/ai/llm/git_command' }
  let(:input_params) { { prompt: 'list 10 commit titles' } }

  before do
    stub_application_setting(openai_api_key: 'test-key')
    stub_licensed_features(ai_git_command: true)
    stub_ee_application_setting(should_check_namespace_plan: true)
  end

  describe 'POST /ai/llm/git_command', :saas do
    let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }

    before_all do
      group.add_developer(current_user)
    end

    include_context 'with ai features enabled for group'

    it_behaves_like 'delegates AI request to Workhorse' do
      let(:expected_params) do
        expected_content = <<~PROMPT
        Provide the appropriate git commands for: list 10 commit titles.
        Respond with JSON format
        ##
        {
          "commands": [The list of commands],
          "explanation": The explanation with the commands wrapped in backticks
        }
        PROMPT

        {
          'URL' => ::Gitlab::Llm::OpenAi::Workhorse::CHAT_URL,
          'Header' => header,
          'Body' => {
            model: 'gpt-3.5-turbo',
            messages: [{
              role: "user",
              content: expected_content
            }],
            temperature: 0.4,
            max_tokens: 300
          }.to_json
        }
      end
    end

    context 'when openai experimentation is unavailable' do
      before do
        stub_feature_flags(openai_experimentation: false)
      end

      it 'returns bad request' do
        post api(url, current_user), params: input_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when git command is unavailable' do
      before do
        stub_feature_flags(ai_git_command_ff: false)
      end

      it 'returns bad request' do
        post api(url, current_user), params: input_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when the endpoint is called too many times' do
      it 'returns too many requests response' do
        expect(Gitlab::ApplicationRateLimiter).to(
          receive(:throttled?).with(:ai_action, scope: [current_user]).and_return(true)
        )

        post api(url, current_user), params: input_params

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end
  end
end
