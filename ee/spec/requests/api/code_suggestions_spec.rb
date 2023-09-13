# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::CodeSuggestions, feature_category: :code_suggestions do
  include WorkhorseHelpers

  let(:current_user) { nil }

  shared_examples 'a response' do |case_name|
    it "returns #{case_name} response", :freeze_time, :aggregate_failures do
      post_api

      expect(response).to have_gitlab_http_status(result)

      expect(json_response).to include(**body)
    end

    it "records Snowplow events" do
      post_api

      if case_name == 'successful'
        expect_snowplow_event(
          category: described_class.name,
          action: :authenticate,
          user: current_user,
          label: 'code_suggestions'
        )
      else
        expect_no_snowplow_event
      end
    end
  end

  shared_examples 'a successful response' do
    include_examples 'a response', 'successful' do
      let(:result) { :created }
      let(:body) do
        {
          'access_token' => kind_of(String),
          'expires_in' => Gitlab::CodeSuggestions::AccessToken::EXPIRES_IN,
          'created_at' => Time.now.to_i
        }
      end
    end
  end

  shared_examples 'an unauthorized response' do
    include_examples 'a response', 'unauthorized' do
      let(:result) { :unauthorized }
      let(:body) do
        { "message" => "401 Unauthorized" }
      end
    end
  end

  shared_examples 'a forbidden response' do
    include_examples 'a response', 'unauthorized' do
      let(:result) { :forbidden }
      let(:body) do
        { "message" => "403 Forbidden" }
      end
    end
  end

  shared_examples 'a not found response' do
    include_examples 'a response', 'not found' do
      let(:result) { :not_found }
      let(:body) do
        { "message" => "404 Not Found" }
      end
    end
  end

  describe 'POST /code_suggestions/tokens' do
    let(:headers) { {} }
    let(:access_code_suggestions) { true }
    let(:is_gitlab_org_or_com) { true }

    subject(:post_api) { post api('/code_suggestions/tokens', current_user), headers: headers }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(an_instance_of(User), :access_code_suggestions, :global)
         .and_return(access_code_suggestions)
      allow(Gitlab).to receive(:org_or_com?).and_return(is_gitlab_org_or_com)
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }

      include_examples 'an unauthorized response'
    end

    context 'when user is logged in' do
      let(:current_user) { create(:user) }

      context 'when API feature flag is disabled' do
        before do
          stub_feature_flags(code_suggestions_tokens_api: false)
        end

        include_examples 'a not found response'
      end

      context 'with no access to code suggestions' do
        let(:access_code_suggestions) { false }

        include_examples 'an unauthorized response'
      end

      context 'with access to code suggestions' do
        context 'when on .org or .com' do
          include_examples 'a successful response'

          it 'sets the access token realm to SaaS' do
            expect(Gitlab::CodeSuggestions::AccessToken).to receive(:new).with(
              current_user, gitlab_realm: Gitlab::CodeSuggestions::AccessToken::GITLAB_REALM_SAAS
            )

            post_api
          end

          context 'when request was proxied from self managed instance' do
            let(:headers) { { 'User-Agent' => 'gitlab-workhorse' } }

            include_examples 'a successful response'

            context 'with instance admin feature flag is disabled' do
              before do
                stub_feature_flags(code_suggestions_for_instance_admin_enabled: false)
              end

              include_examples 'an unauthorized response'
            end

            it 'sets the access token realm to self-managed' do
              expect(Gitlab::CodeSuggestions::AccessToken).to receive(:new).with(
                current_user, gitlab_realm: Gitlab::CodeSuggestions::AccessToken::GITLAB_REALM_SELF_MANAGED
              )

              post_api
            end
          end
        end

        context 'when not on .org and .com' do
          let(:is_gitlab_org_or_com) { false }

          include_examples 'a not found response'
        end
      end
    end
  end

  describe 'POST /code_suggestions/completions' do
    let(:access_code_suggestions) { true }
    let(:global_instance_id) { 'instance-ABC' }
    let(:global_user_id) { 'user-ABC' }
    let(:prefix) { 'def is_even(n: int) ->' }

    let(:body) do
      {
        project_path: "gitlab-org/gitlab-shell",
        project_id: 33191677, # not removed given we still might get it but we will not use it
        current_file: {
          file_name: "test.py",
          content_above_cursor: prefix,
          content_below_cursor: ""
        }
      }
    end

    subject(:post_api) do
      post api('/code_suggestions/completions', current_user), headers: headers, params: body.to_json
    end

    before do
      allow(Gitlab).to receive(:org_or_com?).and_return(is_saas)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(current_user, :access_code_suggestions, :global)
                                          .and_return(access_code_suggestions)

      allow_next_instance_of(API::Helpers::GlobalIds::Generator) do |generator|
        allow(generator).to receive(:generate).with(current_user).and_return([global_instance_id, global_user_id])
      end
    end

    shared_examples 'code completions endpoint' do
      context 'when user is not logged in' do
        let(:current_user) { nil }

        include_examples 'an unauthorized response'
      end

      context 'when user does not have access to code suggestions' do
        let(:access_code_suggestions) { false }

        include_examples 'an unauthorized response'
      end

      context 'when user is logged in' do
        let(:current_user) { create(:user) }

        before do
          stub_env('CODE_SUGGESTIONS_BASE_URL', nil)
        end

        it 'delegates downstream service call to Workhorse with correct auth token' do
          post_api

          expect(response.status).to be(200)
          expect(response.body).to eq("".to_json)
          command, params = workhorse_send_data
          expect(command).to eq('send-url')
          expect(params).to eq({
            'URL' => 'https://codesuggestions.gitlab.com/v2/code/completions',
            'AllowRedirects' => false,
            'Body' => body.merge(prompt_version: 1).to_json,
            'Header' => {
              'X-Gitlab-Authentication-Type' => ['oidc'],
              'X-Gitlab-Instance-Id' => [global_instance_id],
              'X-Gitlab-Global-User-Id' => [global_user_id],
              'X-Gitlab-Realm' => [gitlab_realm],
              'Authorization' => ["Bearer #{token}"],
              'Content-Type' => ['application/json'],
              'User-Agent' => ['Super Awesome Browser 43.144.12']
            },
            'Method' => 'POST'
          })
        end

        context 'when overriding service base URL' do
          before do
            stub_env('CODE_SUGGESTIONS_BASE_URL', 'http://test.com')
          end

          it 'sends requests to this URL instead' do
            post_api

            _, params = workhorse_send_data
            expect(params).to include({
              'URL' => 'http://test.com/v2/code/completions'
            })
          end
        end

        context 'with telemetry headers' do
          let(:headers) do
            {
              'X-Gitlab-Authentication-Type' => 'oidc',
              'X-Gitlab-Oidc-Token' => token,
              'Content-Type' => 'application/json',
              'X-GitLab-CS-Accepts' => 'accepts',
              'X-GitLab-CS-Requests' => "requests",
              'X-GitLab-CS-Errors' => 'errors',
              'X-GitLab-CS-Custom' => 'helloworld',
              'X-GitLab-NO-Ignore' => 'ignoreme',
              'User-Agent' => 'Super Cool Browser 14.5.2'
            }
          end

          it 'proxies appropriate headers to code suggestions service' do
            post_api

            _, params = workhorse_send_data
            expect(params).to include({
              'Header' => {
                'X-Gitlab-Authentication-Type' => ['oidc'],
                'Authorization' => ["Bearer #{token}"],
                'Content-Type' => ['application/json'],
                'X-Gitlab-Instance-Id' => [global_instance_id],
                'X-Gitlab-Global-User-Id' => [global_user_id],
                'X-Gitlab-Realm' => [gitlab_realm],
                'X-Gitlab-Cs-Accepts' => ['accepts'],
                'X-Gitlab-Cs-Requests' => ['requests'],
                'X-Gitlab-Cs-Errors' => ['errors'],
                'X-Gitlab-Cs-Custom' => ['helloworld'],
                'User-Agent' => ['Super Cool Browser 14.5.2']
              }
            })
          end
        end

        context 'when code_generation_no_comment_prefix feature flag enabled' do
          before do
            stub_feature_flags(code_generation_no_comment_prefix: current_user)
          end

          it 'passes skip_generate_comment_prefix: true into TaskSelector.task' do
            expect(::CodeSuggestions::TaskSelector).to receive(:task)
              .with(skip_generate_comment_prefix: true, params: kind_of(Hash))
              .and_call_original

            post_api
          end
        end

        context 'when code_generation_no_comment_prefix feature flag disabled' do
          before do
            stub_feature_flags(code_generation_no_comment_prefix: false)
          end

          it 'passes skip_generate_comment_prefix: false into TaskSelector.task' do
            expect(::CodeSuggestions::TaskSelector).to receive(:task)
              .with(skip_generate_comment_prefix: false, params: kind_of(Hash))
              .and_call_original

            post_api
          end
        end
      end
    end

    context 'when the instance is Gitlab.org_or_com' do
      let(:is_saas) { true }
      let(:gitlab_realm) { 'saas' }
      let_it_be(:token) { 'generated-jwt' }

      let(:headers) do
        {
          'X-Gitlab-Authentication-Type' => 'oidc',
          'X-Gitlab-Oidc-Token' => token,
          'Content-Type' => 'application/json',
          'User-Agent' => 'Super Awesome Browser 43.144.12'
        }
      end

      before do
        allow_next_instance_of(Gitlab::CodeSuggestions::AccessToken) do |instance|
          allow(instance).to receive(:encoded).and_return(token)
        end
      end

      context 'when user does not have active code suggestions purchase' do
        let(:current_user) { create(:user) }

        include_examples 'a not found response'
      end

      context 'when user has active code suggestions purchase' do
        before do
          add_on_purchase = create(:gitlab_subscription_add_on_purchase)
          add_on_purchase.namespace.add_reporter(current_user)
        end

        context 'when the task is code generation' do
          let(:current_user) { create(:user) }
          let(:instruction) { 'A function that outputs the first 20 fibonacci numbers' }
          let(:prefix) do
            <<~PREFIX
              def is_even(n: int) ->
              # #{instruction}
            PREFIX
          end

          let(:prompt) do
            <<~PROMPT
              This is a task to write new Python code in a file 'test.py' based on a given description.
              You get first the already existing code file and then the description of the code that needs to be created.
              It is your task to write valid and working Python code.
              Only return in your response new code.

              Already existing code:

              ```py
              def is_even(n: int) ->
              ```

              Create new code for the following description:
              `#{instruction}`
            PROMPT
          end

          it 'sends requests to the code generation endpoint' do
            expected_body = body.merge(
              prompt_version: 2,
              prompt: prompt
            )

            expect(Gitlab::Workhorse)
              .to receive(:send_url)
              .with(
                'https://codesuggestions.gitlab.com/v2/code/generations',
                hash_including(body: expected_body.to_json)
              )

            post_api
          end
        end

        it_behaves_like 'code completions endpoint'
      end

      context 'when code_suggestions_completion_api feature flag is disabled' do
        let(:current_user) { create(:user) }

        before do
          stub_feature_flags(code_suggestions_completion_api: false)
        end

        include_examples 'a forbidden response'
      end

      context 'when purchase_code_suggestions feature flag is disabled' do
        let(:current_user) { create(:user) }

        before do
          stub_feature_flags(purchase_code_suggestions: false)
        end

        it_behaves_like 'code completions endpoint'
      end
    end

    context 'when the instance is Gitlab self-managed' do
      let(:is_saas) { false }
      let(:gitlab_realm) { 'self-managed' }
      let_it_be(:token) { 'stored-token' }
      let_it_be(:service_access_token) { create(:service_access_token, :code_suggestions, :active, token: token) }

      let(:headers) do
        {
          'X-Gitlab-Authentication-Type' => 'oidc',
          'Content-Type' => 'application/json',
          'User-Agent' => 'Super Awesome Browser 43.144.12'
        }
      end

      it_behaves_like 'code completions endpoint'

      context 'when there is no active code suggestions token' do
        before do
          create(:service_access_token, :code_suggestions, :expired, token: token)
        end

        include_examples 'a response', 'unauthorized' do
          let(:result) { :unauthorized }
          let(:body) do
            { "message" => "401 Unauthorized" }
          end
        end
      end
    end
  end
end
