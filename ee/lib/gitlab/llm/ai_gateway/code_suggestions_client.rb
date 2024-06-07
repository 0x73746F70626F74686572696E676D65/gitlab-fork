# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class CodeSuggestionsClient
        include ::Gitlab::Utils::StrongMemoize
        include ::API::Helpers::CloudConnector

        COMPLETION_CHECK_TIMEOUT = 3.seconds
        DEFAULT_TIMEOUT = 30.seconds

        def initialize(user)
          @user = user
          @logger = Gitlab::Llm::Logger.build
        end

        def test_completion
          return 'Access token is missing' unless access_token

          response = Gitlab::HTTP.post(
            task.endpoint,
            headers: request_headers,
            body: task.body,
            timeout: COMPLETION_CHECK_TIMEOUT,
            allow_local_requests: true
          )

          return "AI Gateway returned code #{response.code}: #{response.body}" unless response.code == 200
          return "Response doesn't contain a completion" unless choice?(response)

          nil
        rescue StandardError => err
          Gitlab::ErrorTracking.track_exception(err)
          err.message
        end

        def direct_access_token
          return error('Missing instance token') unless access_token

          logger.info(message: "Creating user access token")
          response = Gitlab::HTTP.post(
            Gitlab::AiGateway.access_token_url,
            headers: request_headers,
            body: nil,
            timeout: DEFAULT_TIMEOUT,
            allow_local_requests: true,
            stream_body: false
          )
          return error('Token creation failed') unless response.success?
          return error('Token is missing in response') unless response['token'].present?

          success(token: response['token'])
        end

        private

        attr_reader :user, :logger

        def error(message)
          {
            message: message,
            status: :error
          }
        end

        def success(pass_back = {})
          pass_back[:status] = :success
          pass_back
        end

        def request_headers
          {
            'X-Gitlab-Authentication-Type' => 'oidc',
            'Authorization' => "Bearer #{access_token}",
            'Content-Type' => 'application/json',
            'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id
          }.merge(cloud_connector_headers(user))
        end

        def access_token
          ::CloudConnector::AvailableServices.find_by_name(:code_suggestions).access_token(user)
        end
        strong_memoize_attr :access_token

        def choice?(response)
          response['choices']&.first&.dig('text').present?
        end

        def task
          params = {
            current_file: {
              file_name: 'test.rb',
              content_above_cursor: 'def hello_world'
            }
          }
          CodeSuggestions::Tasks::CodeCompletion.new(unsafe_passthrough_params: params)
        end
        strong_memoize_attr :task
      end
    end
  end
end
