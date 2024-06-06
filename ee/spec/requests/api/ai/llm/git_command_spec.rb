# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::Llm::GitCommand, :saas, feature_category: :source_code_management do
  let_it_be(:current_user) { create :user }

  let(:url) { '/ai/llm/git_command' }
  let(:input_params) { { prompt: 'list 10 commit titles' } }
  let(:make_request) { post api(url, current_user), params: input_params }

  before do
    stub_licensed_features(ai_git_command: true)
    stub_ee_application_setting(should_check_namespace_plan: true)
  end

  describe 'POST /ai/llm/git_command', :saas, :use_clean_rails_redis_caching do
    let_it_be(:group, refind: true) { create(:group_with_plan, plan: :ultimate_plan) }

    before_all do
      group.add_developer(current_user)
    end

    include_context 'with ai features enabled for group'

    context 'when delegates AI request to Workhorse' do
      let(:header) do
        {
          'Authorization' => ['Bearer access token'],
          'Content-Type' => ['application/json'],
          'Accept' => ["application/json"],
          'Host' => ['cloud.gitlab.com'],
          'X-Gitlab-Authentication-Type' => ['oidc'],
          'X-Gitlab-Global-User-Id' => anything,
          'X-Gitlab-Host-Name' => anything,
          'X-Gitlab-Instance-Id' => anything,
          'X-Gitlab-Rails-Send-Start' => anything,
          'X-Gitlab-Realm' => anything,
          'X-Gitlab-Unit-Primitive' => ['generate_commit_message'],
          'X-Gitlab-Version' => anything,
          'X-Request-ID' => anything
        }
      end

      let(:expected_params) do
        expected_content = <<~PROMPT
        Provide the appropriate git commands for: list 10 commit titles.

        Respond with git commands wrapped in separate ``` blocks.
        Provide explanation for each command in a separate block.

        ##
        Example:

        ```
        git log -10
        ```

        This command will list the last 10 commits in the current branch.
        PROMPT

        {
          'URL' => "https://cloud.gitlab.com/ai/v1/proxy/vertex-ai/v1/projects/PROJECT/locations/LOCATION/publishers/google/models/codechat-bison:predict",
          'Header' => header,
          'AllowRedirects' => false,
          'Method' => 'POST',
          'Body' => {
            instances: [{
              messages: [{
                author: "content",
                content: expected_content
              }]
            }],
            parameters: {
              temperature: 0.2,
              maxOutputTokens: 2048,
              topK: 40,
              topP: 0.95
            }
          }.to_json
        }
      end

      before do
        stub_ee_application_setting(vertex_ai_host: 'host', vertex_ai_project: 'c')

        allow_next_instance_of(::Gitlab::Llm::VertexAi::Configuration) do |instance|
          allow(instance).to receive(:access_token).and_return('access token')
        end
      end

      it 'responds with Workhorse send-url headers' do
        make_request

        expect(response.body).to eq('""')
        expect(response).to have_gitlab_http_status(:ok)

        send_url_prefix, encoded_data = response.headers['Gitlab-Workhorse-Send-Data'].split(':')
        data = Gitlab::Json.parse(Base64.urlsafe_decode64(encoded_data))

        expect(send_url_prefix).to eq('send-url')
        expect(data).to include(expected_params)
      end
    end

    context 'when ai_global_switch is turned off' do
      before do
        stub_feature_flags(ai_global_switch: false)
      end

      it 'returns bad request' do
        make_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when the endpoint is called too many times' do
      it 'returns too many requests response' do
        expect(Gitlab::ApplicationRateLimiter).to(
          receive(:throttled?).with(:ai_action, scope: [current_user]).and_return(true)
        )

        make_request

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end
  end
end
