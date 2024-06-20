# frozen_string_literal: true

module API
  class CodeSuggestions < ::API::Base
    include APIGuard

    feature_category :code_suggestions

    # a limit used for overall body size when forwarding request to ai-assist
    MAX_BODY_SIZE = 600_000
    MAX_CONTENT_SIZE = 400_000

    MAX_CONTEXT_NAME_SIZE = 255

    allow_access_with_scope :ai_features

    before do
      authenticate!

      not_found! unless Feature.enabled?(:ai_duo_code_suggestions_switch, type: :ops)
      unauthorized! unless current_user.can?(:access_code_suggestions)
    end

    helpers do
      def model_gateway_headers(headers, gateway_token)
        Gitlab::AiGateway.headers(user: current_user, token: gateway_token, agent: headers["User-Agent"])
          .merge(saas_headers)
          .transform_values { |v| Array(v) }
      end

      def connector_public_headers
        Gitlab::CloudConnector.headers(current_user).merge(saas_headers).merge('X-Gitlab-Authentication-Type' => 'oidc')
      end

      def saas_headers
        return {} unless Gitlab.com?

        {
          'X-Gitlab-Saas-Namespace-Ids' => '', # TODO: remove this header entirely once confirmed safe to do so
          'X-Gitlab-Saas-Duo-Pro-Namespace-Ids' => current_user
                                                     .duo_pro_add_on_available_namespace_ids
                                                     .join(',')
        }
      end
    end

    namespace 'code_suggestions' do
      resources :completions do
        params do
          requires :current_file, type: Hash do
            requires :file_name, type: String, limit: 255, desc: 'The name of the current file'
            requires :content_above_cursor, type: String, limit: MAX_CONTENT_SIZE, desc: 'The content above cursor'
            optional :content_below_cursor, type: String, limit: MAX_CONTENT_SIZE, desc: 'The content below cursor'
          end
          optional :intent, type: String, values:
            [
              ::CodeSuggestions::InstructionsExtractor::INTENT_COMPLETION,
              ::CodeSuggestions::InstructionsExtractor::INTENT_GENERATION
            ],
            desc: 'The intent of the completion request, current options are "completion" or "generation"'
          optional :generation_type, type: String, values: ::CodeSuggestions::Instruction::GENERATION_TRIGGER_TYPES,
            desc: 'The type of generation request'
          optional :stream, type: Boolean, default: false, desc: 'The option to stream code completion response'
          optional :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
          optional :user_instruction, type: String, limit: MAX_BODY_SIZE,
            desc: 'Additional instructions provided by a user'
          optional :context, type: Array, allow_blank: false, desc: 'List of related context parts' do
            requires :type, type: String,
              values: ::CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages::CONTENT_TYPES.values,
              desc: 'The type of a related part of context'
            requires :name, type: String, limit: MAX_CONTEXT_NAME_SIZE, allow_blank: false,
              desc: 'The name of a related part of context'
            requires :content, type: String, limit: MAX_BODY_SIZE, allow_blank: false,
              desc: 'The content of a part of context'
          end
        end
        post do
          token = ::CloudConnector::AvailableServices.find_by_name(:code_suggestions).access_token(current_user)

          unauthorized! if token.nil?

          check_rate_limit!(:code_suggestions_api_endpoint, scope: current_user) do
            Gitlab::InternalEvents.track_event(
              'code_suggestions_rate_limit_exceeded',
              user: current_user
            )

            render_api_error!({ error: _('This endpoint has been requested too many times. Try again later.') }, 429)
          end

          task = ::CodeSuggestions::TaskFactory.new(
            current_user,
            params: declared_params(params),
            unsafe_passthrough_params: params.except(:private_token)
          ).task

          body = task.body
          file_too_large! if body.size > MAX_BODY_SIZE

          if Gitlab::Tracking::AiTracking.track_via_code_suggestions?('code_suggestions_requested', current_user)
            Gitlab::Tracking::AiTracking.track_event('code_suggestions_requested', user: current_user)
          end

          workhorse_headers =
            Gitlab::Workhorse.send_url(
              task.endpoint,
              body: body,
              headers: model_gateway_headers(headers, token),
              method: "POST",
              timeouts: { read: 55 }
            )

          header(*workhorse_headers)

          status :ok
          body ''
        end
      end

      resources :direct_access do
        desc 'Connection details for accessing code suggestions directly' do
          success code: 201
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' },
            { code: 429, message: 'Too many requests' }
          ]
        end

        post do
          not_found! unless Feature.enabled?(:code_suggestions_direct_completions, current_user)
          forbidden!('Direct connections are disabled') if Gitlab::CurrentSettings.disabled_direct_code_suggestions

          check_rate_limit!(:code_suggestions_direct_access, scope: current_user) do
            Gitlab::InternalEvents.track_event(
              'code_suggestions_direct_access_rate_limit_exceeded',
              user: current_user
            )

            render_api_error!({ error: _('This endpoint has been requested too many times. Try again later.') }, 429)
          end

          result = Gitlab::Llm::AiGateway::CodeSuggestionsClient.new(current_user).direct_access_token
          service_unavailable!(result[:message]) if result[:status] == :error

          Gitlab::Tracking::AiTracking.track_event('code_suggestion_direct_access_token_refresh', user: current_user)

          access = {
            base_url: ::Gitlab::AiGateway.url,
            # for development purposes we just return instance JWT, this should not be used in production
            # until we generate a short-term token for user
            # https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/issues/429
            token: result[:token],
            expires_at: result[:expires_at],
            headers: connector_public_headers
          }
          present access, with: Grape::Presenters::Presenter
        end
      end

      resources :enabled do
        desc 'Code suggestions enabled for a project' do
          success code: 200
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 403, message: '403 Code Suggestions Disabled' },
            { code: 404, message: 'Not found' }
          ]
        end
        params do
          requires :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
        end

        post do
          path = declared_params[:project_path]

          not_found! if path.empty?

          projects = ::ProjectsFinder.new(params: { full_paths: [path] }, current_user: current_user).execute

          not_found! if projects.none?

          forbidden! unless projects.first.project_setting.duo_features_enabled?

          status :ok
        end
      end
    end
  end
end
