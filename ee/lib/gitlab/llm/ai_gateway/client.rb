# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class Client
        include ::Gitlab::Llm::Concerns::ExponentialBackoff
        include Langsmith::RunHelpers

        DEFAULT_TIMEOUT = 30.seconds

        ConnectionError = Class.new(StandardError)

        def initialize(user, service_name:, tracking_context: {})
          @user = user
          @access_token = ::CloudConnector::AvailableServices.find_by_name(service_name).access_token(user)
          @tracking_context = tracking_context
          @logger = Gitlab::Llm::Logger.build
        end

        def complete(endpoint:, body:, timeout: DEFAULT_TIMEOUT)
          return unless enabled?

          response = retry_with_exponential_backoff do
            perform_completion_request(endpoint: endpoint, body: body, timeout: timeout, stream: false)
          end

          logger.info_or_debug(user, message: "Received response from AI Gateway", response: response.parsed_response)

          response
        end

        def stream(endpoint:, body:, timeout: DEFAULT_TIMEOUT)
          return unless enabled?

          response_body = ""

          response = perform_completion_request(
            endpoint: endpoint, body: body, timeout: timeout, stream: true
          ) do |chunk|
            response_body += chunk

            yield chunk if block_given?
          end

          if response.success?
            logger.info_or_debug(user, message: "Received response from AI Gateway", response: response_body)

            response_body
          else
            logger.error(message: "Received error from AI gateway", response: response_body)

            raise ConnectionError, 'AI gateway not reachable'
          end
        end
        traceable :stream, name: 'Request to AI Gateway', run_type: 'llm'

        private

        attr_reader :user, :access_token, :logger, :tracking_context

        def perform_completion_request(endpoint:, body:, timeout:, stream:)
          logger.info_or_debug(user, message: "Performing request to AI Gateway", body: body, timeout: timeout,
            stream: stream)

          Gitlab::HTTP.post(
            "#{Gitlab::AiGateway.url}#{endpoint}",
            headers: Gitlab::AiGateway.headers(user: user, token: access_token),
            body: body.to_json,
            timeout: timeout,
            allow_local_requests: true,
            stream_body: stream
          ) do |fragment|
            yield fragment if block_given?
          end
        end

        def enabled?
          access_token.present?
        end
      end
    end
  end
end
