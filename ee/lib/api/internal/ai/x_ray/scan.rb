# frozen_string_literal: true

# rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- This feature is developed on extremely short notice,
# so I follow existing code patterns in code suggestions AddOn Flow.
module API
  module Internal
    module Ai
      module XRay
        class Scan < ::API::Base
          feature_category :code_suggestions

          helpers ::API::Ci::Helpers::Runner
          helpers ::API::Helpers::CloudConnector

          before do
            authenticate_job!
            not_found! unless x_ray_enabled_on_instance?
            unauthorized! unless x_ray_available?
          end

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            def x_ray_enabled_on_instance?
              return true if ::Gitlab::Saas.feature_available?(:code_suggestions_x_ray)
              return false unless ::License.feature_available?(:code_suggestions)

              ::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.any?
            end

            def x_ray_available?
              if ::Gitlab::Saas.feature_available?(:code_suggestions_x_ray)
                gitlab_duo_pro_add_on?
              else
                ai_gateway_token.present?
              end
            end

            def gitlab_duo_pro_add_on?
              ::GitlabSubscriptions::AddOnPurchase
                .for_gitlab_duo_pro
                .by_namespace_id(current_namespace.self_and_ancestor_ids)
                .active
                .any?
            end

            def model_gateway_headers(headers, gateway_token)
              {
                'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
                'X-Gitlab-Authentication-Type' => 'oidc',
                'Authorization' => "Bearer #{gateway_token}",
                'Content-Type' => 'application/json',
                'User-Agent' => headers["User-Agent"] # Forward the User-Agent on to the model gateway
              }.merge(saas_headers).merge(cloud_connector_headers(current_job.user)).transform_values { |v| Array(v) }
            end

            def saas_headers
              return {} unless Gitlab.com?

              {
                'X-Gitlab-Saas-Namespace-Ids' => [current_namespace.id.to_s]
              }
            end

            def current_namespace
              current_job.namespace
            end
            strong_memoize_attr :current_namespace

            def ai_gateway_token
              Gitlab::Llm::AiGateway::Client.access_token(scopes: [:code_suggestions])
            end
            strong_memoize_attr :ai_gateway_token
          end

          namespace 'internal' do
            resource :jobs do
              params do
                requires :id, type: Integer, desc: %q(Job's ID)
                requires :token, type: String, desc: %q(Job's authentication token)
              end
              post ':id/x_ray/scan' do
                check_rate_limit!(:code_suggestions_x_ray_scan, scope: current_job.project)

                workhorse_headers =
                  Gitlab::Workhorse.send_url(
                    File.join(::CodeSuggestions::Tasks::Base.base_url, 'v1', 'x-ray', 'libraries'),
                    body: params.except(:token, :id).to_json,
                    headers: model_gateway_headers(headers, ai_gateway_token),
                    method: "POST"
                  )

                header(*workhorse_headers)
                status :ok
              end
            end
          end
        end
      end
    end
  end
end
# rubocop: enable Gitlab/AvoidGitlabInstanceChecks
