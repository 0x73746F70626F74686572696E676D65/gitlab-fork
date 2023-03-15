# frozen_string_literal: true

module ProductAnalytics
  class CubeDataQueryService < BaseContainerService
    REFRESH_TOKEN_EXPIRE = 1.day

    def execute
      error = cannot_query_data?

      error.nil? ? query_data : error
    end

    def cannot_query_data?
      unless product_analytics_enabled?
        return ServiceResponse.error(message: 'Product Analytics is not enabled', reason: :not_found)
      end

      return ServiceResponse.error(message: 'Access Denied', reason: :unauthorized) unless has_access?

      ServiceResponse.error(message: 'Must provide a url to query', reason: :bad_request) unless params[:path].present?
    end

    private

    def query_data
      options = {
        allow_local_requests: true,
        headers: cube_security_headers
      }

      response = if params[:path] == 'meta'
                   Gitlab::HTTP.get(cube_server_url(params[:path]), options)
                 else
                   ::Gitlab::HTTP.post(
                     cube_server_url(params[:path]),
                     options.merge(body: { query: params[:query], queryType: params[:queryType] }.to_json)
                   )
                 end

      begin
        body = Gitlab::Json.parse(response.body)
      rescue Gitlab::Json.parser_error => e
        return ServiceResponse.error(message: e.message, reason: :bad_gateway)
      end

      if database_exists?(body)
        ServiceResponse.success(message: 'Cube Query Successful', payload: body)
      else
        ServiceResponse.error(message: '404 Clickhouse Database Not Found', reason: :not_found)
      end
    end

    def product_analytics_enabled?
      Gitlab::CurrentSettings.product_analytics_enabled? &&
        Gitlab::CurrentSettings.cube_api_base_url.present? &&
        Gitlab::CurrentSettings.cube_api_key.present? &&
        project.product_analytics_enabled?
    end

    def has_access?
      can?(current_user, :developer_access, project)
    end

    def cube_server_url(endpoint)
      "#{Gitlab::CurrentSettings.cube_api_base_url}/cubejs-api/v1/" + endpoint
    end

    def gitlab_token
      return unless params[:include_token]

      ::ResourceAccessTokens::CreateService.new(
        current_user,
        project,
        { expires_at: REFRESH_TOKEN_EXPIRE.from_now }).execute.payload[:access_token]&.token
    end

    def cube_security_headers
      payload = {
        iat: Time.now.utc.to_i,
        exp: Time.now.utc.to_i + 180,
        appId: "gitlab_project_#{project.id}",
        gitlabToken: gitlab_token,
        iss: ::Settings.gitlab.host
      }

      {
        "Content-Type": 'application/json',
        Authorization: JWT.encode(payload, Gitlab::CurrentSettings.cube_api_key, 'HS256')
      }
    end

    def database_exists?(body)
      (body['error'] =~ %r{\AError: Code: (81|60)\..*(UNKNOWN_DATABASE|UNKNOWN_TABLE)}).nil?
    end
  end
end
