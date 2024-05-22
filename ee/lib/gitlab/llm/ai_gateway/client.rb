# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class Client
        extend ::Gitlab::Utils::Override

        include ::Gitlab::Llm::Concerns::ExponentialBackoff
        include ::Gitlab::Llm::Concerns::EventTracking
        include ::Gitlab::Llm::Concerns::AvailableModels
        include ::Gitlab::Llm::Concerns::AllowedParams
        include ::Gitlab::Utils::StrongMemoize
        include ::API::Helpers::CloudConnector
        include Langsmith::RunHelpers

        DEFAULT_TIMEOUT = 30.seconds
        DEFAULT_TYPE = 'prompt'
        DEFAULT_SOURCE = 'GitLab EE'
        CHAT_ENDPOINT = '/v1/chat/agent'

        JWT_AUDIENCE = 'gitlab-ai-gateway'

        ConnectionError = Class.new(StandardError)

        def initialize(user, tracking_context: {})
          @user = user
          @tracking_context = tracking_context
          @logger = Gitlab::Llm::Logger.build
        end

        def complete(prompt:, **options)
          return unless enabled? && model_provider_valid?(options)

          # We do not allow to set `stream` because the separate `#stream` method should be used for streaming.
          # The reason is that streaming the response would not work with the exponential backoff mechanism.
          response = retry_with_exponential_backoff do
            perform_completion_request(prompt: prompt, options: options.except(:stream))
          end

          logger.info_or_debug(user, message: "Received response from AI Gateway", response: response["response"])

          track_prompt_size(token_size(prompt), provider(options))
          track_response_size(token_size(response["response"]), provider(options))

          response
        end

        def stream(prompt:, **options)
          return unless enabled? && model_provider_valid?(options)

          response_body = ""

          response = perform_completion_request(prompt: prompt, options: options.merge(stream: true)) do |chunk|
            response_body += chunk

            yield chunk if block_given?
          end

          if response.success?
            logger.info_or_debug(user, message: "Received response from AI Gateway", response: response_body)

            track_prompt_size(token_size(prompt), provider(options))
            track_response_size(token_size(response_body), provider(options))

            response_body
          else
            logger.error(message: "Received error from AI gateway", response: response_body)

            raise ConnectionError, 'AI gateway not reachable'
          end
        end
        traceable :stream, name: 'Request to AI Gateway', run_type: 'llm'

        private

        attr_reader :user, :logger, :tracking_context

        def perform_completion_request(prompt:, options:)
          logger.info_or_debug(user, message: "Performing request to AI Gateway", prompt: prompt, options: options)
          timeout = options.delete(:timeout) || DEFAULT_TIMEOUT

          Gitlab::HTTP.post(
            "#{Gitlab::AiGateway.url}#{endpoint_url(options)}",
            headers: request_headers,
            body: request_body(prompt: prompt, options: options).to_json,
            timeout: timeout,
            allow_local_requests: true,
            stream_body: options.fetch(:stream, false)
          ) do |fragment|
            yield fragment if block_given?
          end
        end

        def enabled?
          chat_access_token.present?
        end

        def model_provider_valid?(options)
          provider(options)
        end

        def request_headers
          {
            'X-Gitlab-Authentication-Type' => 'oidc',
            'Authorization' => "Bearer #{chat_access_token}",
            'Content-Type' => 'application/json',
            'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id
          }.merge(cloud_connector_headers(user))
        end

        def chat_access_token
          ::CloudConnector::AvailableServices.find_by_name(:duo_chat).access_token(user)
        end
        strong_memoize_attr :chat_access_token

        def request_body(prompt:, options: {})
          {
            prompt_components: [{
              type: DEFAULT_TYPE,
              metadata: {
                source: DEFAULT_SOURCE,
                version: Gitlab.version_info.to_s
              },
              payload: {
                content: prompt,
                provider: provider(options),
                model: model(options)
              }.merge(payload_params(options))
            }],
            stream: options.fetch(:stream, false)
          }
        end

        def payload_params(options)
          allowed_params = ALLOWED_PARAMS.fetch(provider(options))
          params = options.slice(*allowed_params)

          return {} if params.empty?

          { params: params }
        end

        def token_size(content)
          # Anthropic's APIs don't send used tokens as part of the response, so
          # instead we estimate the number of tokens based on typical token size -
          # one token is roughly 4 chars.
          content.to_s.size / 4
        end

        def endpoint_url(options)
          options.fetch(:endpoint_url, CHAT_ENDPOINT)
        end

        def model(options)
          return options[:model] if options[:model].present?

          CLAUDE_3_SONNET
        end

        def provider(options)
          AVAILABLE_MODELS.find do |_, models|
            models.include?(model(options))
          end&.first
        end

        override :tracking_class_name
        def tracking_class_name(provider)
          TRACKING_CLASS_NAMES.fetch(provider)
        end
      end
    end
  end
end
