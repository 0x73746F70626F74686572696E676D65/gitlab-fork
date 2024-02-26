# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Ai::XRay::Scan, feature_category: :code_suggestions do
  describe 'POST /internal/jobs/:id/x_ray/scan' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:job) { create(:ci_build, :running, namespace: namespace) }

    let(:ai_gateway_token) { 'ai gateway token' }
    let(:instance_uuid) { "uuid-not-set" }
    let(:hostname) { "localhost" }
    let(:api_url) { "/internal/jobs/#{job.id}/x_ray/scan" }
    let(:headers) { {} }
    let(:namespace_workhorse_headers) { {} }
    let(:params) do
      {
        token: job.token,
        prompt_components: [{ payload: "test" }]
      }
    end

    let(:base_workhorse_headers) do
      {
        "X-Gitlab-Authentication-Type" => ["oidc"],
        "Authorization" => ["Bearer #{ai_gateway_token}"],
        "Content-Type" => ["application/json"],
        "User-Agent" => [],
        "X-Gitlab-Host-Name" => [hostname],
        "X-Gitlab-Instance-Id" => [instance_uuid],
        "X-Gitlab-Realm" => [gitlab_realm]
      }
    end

    subject(:post_api) do
      post api(api_url), params: params, headers: headers
    end

    context 'when job token is missing' do
      let(:params) do
        {
          prompt_components: [{ payload: "test" }]
        }
      end

      it 'returns Forbidden status' do
        post_api

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    shared_examples 'successful send request via workhorse' do
      let(:endpoint) { 'https://cloud.gitlab.com/ai/v1/x-ray/libraries' }

      shared_examples 'sends request to the XRay libraries' do
        it 'sends requests to the XRay libraries AI Gateway endpoint', :aggregate_failures do
          expected_body = params.except(:token)
          expect(Gitlab::Workhorse)
            .to receive(:send_url)
                  .with(
                    endpoint,
                    body: expected_body.to_json,
                    method: "POST",
                    headers: base_workhorse_headers.merge(namespace_workhorse_headers))
          post_api

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      include_examples 'sends request to the XRay libraries'
    end

    context 'when on self-managed' do
      let(:gitlab_realm) { "self-managed" }

      context 'without code suggestion license feature' do
        before do
          stub_licensed_features(code_suggestions: false)
        end

        it 'returns NOT_FOUND status' do
          post_api

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with code suggestion license feature' do
        before do
          stub_licensed_features(code_suggestions: true)
        end

        # TODO: clean up date-related tests after the Code Suggestions service start date (15.02.2024)
        context 'when before the service start date' do
          around do |example|
            travel_to(CodeSuggestions::SelfManaged::SERVICE_START_DATE - 1.day) do
              example.run
            end
          end

          context 'with code suggestions disabled on instance level' do
            before do
              stub_ee_application_setting(instance_level_code_suggestions_enabled: false)
            end

            it 'returns NOT_FOUND status' do
              post_api

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'with code suggestions enabled on instance level' do
            before do
              stub_ee_application_setting(instance_level_code_suggestions_enabled: true)
            end

            it 'calls ::CloudConnector::AccessService to obtain access token', :aggregate_failures do
              expect_next_instance_of(::CloudConnector::AccessService) do |instance|
                expect(instance).to receive(:access_token).with([:code_suggestions]).and_return(ai_gateway_token)
              end

              post_api

              expect(response).to have_gitlab_http_status(:ok)
            end

            context 'when cloud connector access token is missing' do
              before do
                allow_next_instance_of(::CloudConnector::AccessService) do |instance|
                  allow(instance).to receive(:access_token).and_return(nil)
                end
              end

              it 'returns UNAUTHORIZED status' do
                post_api

                expect(response).to have_gitlab_http_status(:unauthorized)
              end
            end

            context 'when cloud connector access token is valid' do
              before do
                allow_next_instance_of(::CloudConnector::AccessService) do |instance|
                  allow(instance).to receive(:access_token).and_return(ai_gateway_token)
                end
              end

              context 'when instance has uuid available' do
                let(:instance_uuid) { 'some uuid' }

                before do
                  allow(Gitlab::CurrentSettings).to receive(:uuid).and_return(instance_uuid)
                end

                it_behaves_like 'successful send request via workhorse'
              end

              context 'when instance has custom hostname' do
                let(:hostname) { 'gitlab.local' }

                before do
                  stub_config(gitlab: {
                    protocol: 'http',
                    host: hostname,
                    url: "http://#{hostname}",
                    relative_url_root: "http://#{hostname}"
                  })
                end

                it_behaves_like 'successful send request via workhorse'
              end
            end
          end
        end

        context 'when it is past the code suggestions service start date' do
          around do |example|
            travel_to(::CodeSuggestions::SelfManaged::SERVICE_START_DATE + 1.second) do
              example.run
            end
          end

          context 'with out add on' do
            it 'returns NOT_FOUND status' do
              post_api

              expect(response).to have_gitlab_http_status(:not_found)
            end
          end

          context 'with add on' do
            before_all { create(:gitlab_subscription_add_on_purchase, namespace: namespace) }

            it 'calls ::CloudConnector::AccessService to obtain access token', :aggregate_failures do
              expect_next_instance_of(::CloudConnector::AccessService) do |instance|
                expect(instance).to receive(:access_token).with([:code_suggestions]).and_return(ai_gateway_token)
              end

              post_api

              expect(response).to have_gitlab_http_status(:ok)
            end

            context 'when cloud connector access token is missing' do
              before do
                allow_next_instance_of(::CloudConnector::AccessService) do |instance|
                  allow(instance).to receive(:access_token).and_return(nil)
                end
              end

              it 'returns UNAUTHORIZED status' do
                post_api

                expect(response).to have_gitlab_http_status(:unauthorized)
              end
            end

            context 'when cloud connector access token is valid' do
              before do
                allow_next_instance_of(::CloudConnector::AccessService) do |instance|
                  allow(instance).to receive(:access_token).and_return(ai_gateway_token)
                end
              end

              context 'when instance has uuid available' do
                let(:instance_uuid) { 'some uuid' }

                before do
                  allow(Gitlab::CurrentSettings).to receive(:uuid).and_return(instance_uuid)
                end

                it_behaves_like 'successful send request via workhorse'
              end

              context 'when instance has custom hostname' do
                let(:hostname) { 'gitlab.local' }

                before do
                  stub_config(gitlab: {
                    protocol: 'http',
                    host: hostname,
                    url: "http://#{hostname}",
                    relative_url_root: "http://#{hostname}"
                  })
                end

                it_behaves_like 'successful send request via workhorse'
              end
            end
          end
        end
      end
    end

    context 'when on SaaS instance', :saas do
      let_it_be(:code_suggestion_add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }

      let(:gitlab_realm) { "saas" }
      let(:namespace_workhorse_headers) do
        {
          "X-Gitlab-Saas-Namespace-Ids" => [namespace.id.to_s]
        }
      end

      before_all do
        create(
          :gitlab_subscription_add_on_purchase,
          :active,
          add_on: code_suggestion_add_on,
          namespace: namespace
        )
      end

      before do
        allow_next_instance_of(::CloudConnector::AccessService) do |instance|
          allow(instance).to receive(:access_token).and_return(ai_gateway_token)
        end
      end

      context 'with purchase_code_suggestions feature disabled' do
        before do
          stub_feature_flags(purchase_code_suggestions: false)
        end

        context 'with code suggestions enabled on namespace level' do
          let(:namespace_workhorse_headers) do
            {
              "X-Gitlab-Saas-Namespace-Ids" => [namespace.id.to_s]
            }
          end

          it_behaves_like 'successful send request via workhorse'
        end
      end

      context 'with purchase_code_suggestions feature enabled' do
        before do
          stub_feature_flags(purchase_code_suggestions: true)
        end

        it_behaves_like 'successful send request via workhorse'

        context 'when add on subscription is expired' do
          let(:namespace_without_expired_ai_access) { create(:group) }
          let(:job_without_ai_access) { create(:ci_build, :running, namespace: namespace_without_expired_ai_access) }
          let(:api_url) { "/internal/jobs/#{job_without_ai_access.id}/x_ray/scan" }

          let(:params) do
            {
              token: job_without_ai_access.token,
              prompt_components: [{ payload: "test" }]
            }
          end

          before do
            create(
              :gitlab_subscription_add_on_purchase,
              :expired,
              add_on: code_suggestion_add_on,
              namespace: namespace_without_expired_ai_access
            )
          end

          it 'returns UNAUTHORIZED status' do
            post_api

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end

        context 'when job does not have AI access' do
          let(:namespace_without_ai_access) { create(:group) }
          let(:job_without_ai_access) { create(:ci_build, :running, namespace: namespace_without_ai_access) }
          let(:api_url) { "/internal/jobs/#{job_without_ai_access.id}/x_ray/scan" }

          let(:params) do
            {
              token: job_without_ai_access.token,
              prompt_components: [{ payload: "test" }]
            }
          end

          it 'returns UNAUTHORIZED status' do
            post_api

            expect(response).to have_gitlab_http_status(:unauthorized)
          end

          context 'with personal namespace' do
            let(:user_namespace) { create(:user).namespace }
            let(:job_in_user_namespace) { create(:ci_build, :running, namespace: user_namespace) }
            let(:api_url) { "/internal/jobs/#{job_in_user_namespace.id}/x_ray/scan" }

            let(:params) do
              {
                token: job_in_user_namespace.token,
                prompt_components: [{ payload: "test" }]
              }
            end

            let(:namespace_workhorse_headers) do
              {
                "X-Gitlab-Saas-Namespace-Ids" => [user_namespace.id.to_s]
              }
            end

            it 'returns UNAUTHORIZED status' do
              post_api

              expect(response).to have_gitlab_http_status(:unauthorized)
            end
          end
        end
      end
    end
  end
end
