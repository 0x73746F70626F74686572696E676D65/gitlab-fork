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

          PURCHASE_NOT_FOUND_MESSAGE = "GitLab Duo Pro Add-On purchase can't be found"
          TOKEN_NOT_FOUND_MESSAGE = "GitLab Duo Pro Add-On access token missing. Please synchronise Add-On access token"

          before do
            authenticate_job!
            not_found! unless can?(current_user, :access_x_ray_on_instance)
            unauthorized!(TOKEN_NOT_FOUND_MESSAGE) unless token_available?
            unauthorized!(PURCHASE_NOT_FOUND_MESSAGE) unless x_ray_available?
          end

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            def x_ray_available?
              code_suggestions_data.purchased?(current_namespace)
            end

            def token_available?
              ai_gateway_token.present?
            end

            def code_suggestions_data
              CloudConnector::AvailableServices.find_by_name(:code_suggestions)
            end

            def model_gateway_headers(headers, gateway_token)
              Gitlab::AiGateway.headers(user: current_job.user, token: gateway_token, agent: headers["User-Agent"])
                .merge(saas_headers)
                .transform_values { |v| Array(v) }
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
              code_suggestions_data.access_token(current_namespace)
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
