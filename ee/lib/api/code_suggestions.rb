# frozen_string_literal: true

module API
  class CodeSuggestions < ::API::Base
    feature_category :code_suggestions

    helpers ::API::Helpers::GlobalIds

    USER_CODE_SUGGESTIONS_ADD_ON_CACHE_KEY = 'user-%{user_id}-code-suggestions-add-on-cache'

    before do
      authenticate!

      not_found! unless Feature.enabled?(:code_suggestions_tokens_api, type: :ops)
      unauthorized! unless user_allowed?
    end

    helpers do
      def user_allowed?
        current_user.can?(:access_code_suggestions) && access_code_suggestions_when_proxied_to_saas?
      end

      def active_code_suggestions_purchase?
        return true unless ::Feature.enabled?(:purchase_code_suggestions)

        cache_key = format(USER_CODE_SUGGESTIONS_ADD_ON_CACHE_KEY, user_id: current_user.id)
        Rails.cache.fetch(cache_key, expires_in: 1.hour) { current_user.code_suggestions_add_on_available? }
      end

      def model_gateway_headers(headers, gateway_token)
        telemetry_headers = headers.select { |k| /\Ax-gitlab-cs-/i.match?(k) }

        instance_id, user_id = global_instance_and_user_id_for(current_user)
        {
          'X-Gitlab-Instance-Id' => instance_id,
          'X-Gitlab-Global-User-Id' => user_id,
          'X-Gitlab-Realm' => gitlab_realm,
          'X-Gitlab-Authentication-Type' => 'oidc',
          'Authorization' => "Bearer #{gateway_token}",
          'Content-Type' => 'application/json',
          'User-Agent' => headers["User-Agent"] # Forward the User-Agent on to the model gateway
        }.merge(telemetry_headers).transform_values { |v| Array(v) }
      end

      # In case the request was proxied from the self-managed instance,
      # we have an extra check on Gitlab.com if FF is enabled for self-managed admin.
      # The FF is used for gradual rollout for handpicked self-managed customers interested to use code suggestions.
      #
      # NOTE: This code path is being phased out as part of working towards GA for code suggestions.
      # See https://gitlab.com/groups/gitlab-org/-/epics/11114
      def access_code_suggestions_when_proxied_to_saas?
        proxied = proxied?

        raise 'Proxying is only supported under .org or .com' if proxied && !Gitlab.org_or_com?

        !proxied || Feature.enabled?(:code_suggestions_for_instance_admin_enabled, current_user)
      end

      def proxied?
        !!request.headers['User-Agent']&.starts_with?('gitlab-workhorse')
      end

      def gitlab_realm
        # NOTE: This code path is being phased out as part of working towards GA for code suggestions.
        # See https://gitlab.com/groups/gitlab-org/-/epics/11114
        return Gitlab::CodeSuggestions::AccessToken::GITLAB_REALM_SELF_MANAGED if proxied?

        return Gitlab::CodeSuggestions::AccessToken::GITLAB_REALM_SAAS if Gitlab.org_or_com?

        Gitlab::CodeSuggestions::AccessToken::GITLAB_REALM_SELF_MANAGED
      end
    end

    namespace 'code_suggestions' do
      resources :tokens do
        desc 'Create an access token' do
          detail 'Creates an access token to access Code Suggestions.'
          success Entities::CodeSuggestionsAccessToken
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' }
          ]
        end
        post do
          not_found! unless Gitlab.org_or_com?

          Gitlab::Tracking.event(
            'API::CodeSuggestions',
            :authenticate,
            user: current_user,
            label: 'code_suggestions'
          )

          token = Gitlab::CodeSuggestions::AccessToken.new(current_user, gitlab_realm: gitlab_realm)
          present token, with: Entities::CodeSuggestionsAccessToken
        end
      end

      resources :completions do
        post do
          if Gitlab.org_or_com?
            forbidden! unless ::Feature.enabled?(:code_suggestions_completion_api, current_user)
            not_found! unless active_code_suggestions_purchase?

            token = Gitlab::CodeSuggestions::AccessToken.new(
              current_user,
              gitlab_realm: gitlab_realm
            ).encoded
          else
            code_suggestions_token = ::Ai::ServiceAccessToken.code_suggestions.active.last
            unauthorized! if code_suggestions_token.nil?

            token = code_suggestions_token.token
          end

          task = ::CodeSuggestions::TaskSelector.task(
            params: params.except(:private_token)
          )

          workhorse_headers =
            Gitlab::Workhorse.send_url(
              task.endpoint,
              body: task.body,
              headers: model_gateway_headers(headers, token),
              method: "POST"
            )

          header(*workhorse_headers)

          status :ok
          body ''
        end
      end
    end
  end
end
