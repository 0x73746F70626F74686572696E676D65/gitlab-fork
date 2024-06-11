# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Ai::XRay::Scan, feature_category: :code_suggestions do
  describe 'POST /internal/jobs/:id/x_ray/scan' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:sub_namespace) { create(:group, parent: namespace) }
    let_it_be(:user) { create(:user) }
    let_it_be(:job) { create(:ci_build, :running, namespace: namespace, user: user) }
    let_it_be(:sub_job) { create(:ci_build, :running, namespace: sub_namespace, user: user) }
    let_it_be(:code_suggestion_add_on) { create(:gitlab_subscription_add_on) }

    let(:ai_gateway_token) { 'ai gateway token' }
    let(:instance_uuid) { "uuid-not-set" }
    let(:global_user_id) { "user-id" }
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
        "X-Gitlab-Realm" => [gitlab_realm],
        "X-Gitlab-Global-User-Id" => [global_user_id],
        "X-Gitlab-Version" => [Gitlab.version_info.to_s]
      }
    end

    subject(:post_api) do
      post api(api_url), params: params, headers: headers
    end

    before do
      allow_next_instance_of(API::Helpers::GlobalIds::Generator) do |generator|
        allow(generator).to receive(:generate)
                              .with(job.user)
                              .and_return([instance_uuid, global_user_id])
      end
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

    context 'when on self-managed', :with_cloud_connector do
      let(:gitlab_realm) { "self-managed" }

      before do
        ::CloudConnector::AvailableServices.clear_memoization(:access_data_reader)
        ::CloudConnector::AvailableServices.clear_memoization(:available_services)
      end

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

        context 'without add on' do
          it 'returns NOT_FOUND status' do
            post_api

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end

        context 'with add on' do
          before_all { create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: code_suggestion_add_on) }

          context 'when cloud connector access token is missing' do
            let(:ai_gateway_token) { nil }

            it 'returns UNAUTHORIZED status' do
              post_api

              expect(response).to have_gitlab_http_status(:unauthorized)
            end
          end

          context 'when cloud connector access token is valid' do
            before do
              allow(::CloudConnector::ServiceAccessToken)
                .to receive_message_chain(:active, :last, :token)
                .and_return(ai_gateway_token)
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

    context 'when on Gitlab.com instance', :saas do
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
        allow_next_instance_of(::Gitlab::CloudConnector::SelfIssuedToken) do |token|
          allow(token).to receive(:encoded).and_return(ai_gateway_token)
        end
        ::CloudConnector::AvailableServices.clear_memoization(:access_data_reader)
        ::CloudConnector::AvailableServices.clear_memoization(:available_services)
      end

      it_behaves_like 'successful send request via workhorse'

      it_behaves_like 'rate limited endpoint', rate_limit_key: :code_suggestions_x_ray_scan do
        def request
          post api(api_url), params: params, headers: headers
        end
      end

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

        context 'with code suggestions enabled on parent namespace level' do
          let(:namespace_workhorse_headers) do
            {
              "X-Gitlab-Saas-Namespace-Ids" => [sub_namespace.id.to_s]
            }
          end

          let(:params) do
            {
              token: sub_job.token,
              prompt_components: [{ payload: "test" }]
            }
          end

          let(:api_url) { "/internal/jobs/#{sub_job.id}/x_ray/scan" }

          it_behaves_like 'successful send request via workhorse'
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
