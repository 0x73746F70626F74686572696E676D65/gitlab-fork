# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      class Client
        include ::Gitlab::Llm::Concerns::ExponentialBackoff
        include ::Gitlab::Llm::Concerns::EventTracking
        include ::Gitlab::Llm::Concerns::AvailableModels
        include Langsmith::RunHelpers

        DEFAULT_TEMPERATURE = 0
        DEFAULT_MAX_TOKENS = 2048
        DEFAULT_TIMEOUT = 30.seconds

        def initialize(user, unit_primitive:, tracking_context: {})
          @user = user
          @tracking_context = tracking_context
          @unit_primitive = unit_primitive
          @logger = Gitlab::Llm::Logger.build
        end

        def complete(prompt:, **options)
          return unless enabled?

          # We do not allow to set `stream` because the separate `#stream` method should be used for streaming.
          # The reason is that streaming the response would not work with the exponential backoff mechanism.
          response = retry_with_exponential_backoff do
            perform_completion_request(prompt: prompt, options: options.except(:stream))
          end

          response_completion = response["completion"]
          logger.info_or_debug(user, message: "Received response from Anthropic", response: response_completion)

          track_prompt_size(token_size(prompt))
          track_response_size(token_size(response_completion))

          response
        end

        def stream(prompt:, **options)
          return unless enabled?

          response_body = ""

          perform_completion_request(prompt: prompt, options: options.merge(stream: true)) do |parsed_event|
            response_body += parsed_event["completion"] if parsed_event["completion"]

            yield parsed_event if block_given?
          end

          logger.info_or_debug(user, message: "Received response from Anthropic", response: response_body)

          track_prompt_size(token_size(prompt))
          track_response_size(token_size(response_body))

          response_body
        end
        traceable :stream, name: 'Request to Anthropic', run_type: 'llm'

        def messages_complete(messages:, **options)
          return unless enabled?

          # We do not allow to set `stream` because the separate `#stream` method should be used for streaming.
          # The reason is that streaming the response would not work with the exponential backoff mechanism.
          response = retry_with_exponential_backoff do
            perform_messages_request(messages: messages, options: options.except(:stream))
          end

          response_completion = response.dig('content', 0, 'text')
          logger.info_or_debug(user, message: "Received response from Anthropic", response: response_completion)

          track_prompt_size(token_size(messages))
          track_response_size(token_size(response_completion))

          response
        end

        private

        attr_reader :user, :logger, :tracking_context, :unit_primitive

        def perform_completion_request(prompt:, options:)
          logger.info(message: "Performing request to Anthropic", options: options)
          timeout = options.delete(:timeout) || DEFAULT_TIMEOUT

          Gitlab::HTTP.post(
            "#{url}/v1/complete",
            headers: request_headers,
            body: request_body(prompt: prompt, options: options).to_json,
            timeout: timeout,
            allow_local_requests: true,
            stream_body: options.fetch(:stream, false)
          ) do |fragment|
            parse_sse_events(fragment).each do |parsed_event|
              yield parsed_event if block_given?
            end
          end
        end

        def perform_messages_request(messages:, options:)
          logger.info(message: "Performing request to Anthropic", options: options)
          timeout = options.delete(:timeout) || DEFAULT_TIMEOUT

          response = Gitlab::HTTP.post(
            "#{url}/v1/messages",
            headers: request_headers,
            body: request_body_for_messages(messages: messages, options: options).to_json,
            timeout: timeout,
            allow_local_requests: true,
            stream_body: options.fetch(:stream, false)
          )

          raise Gitlab::AiGateway::ForbiddenError if response.forbidden?

          response
        end

        def enabled?
          api_key.present?
        end

        def url
          "#{Gitlab::AiGateway.url}/v1/proxy/anthropic"
        end

        def api_key
          ::CloudConnector::AvailableServices.find_by_name(:anthropic_proxy).access_token(user)
        end

        # We specificy the `anthropic-version` header to receive the stream word by word instead of the accumulated
        # response https://docs.anthropic.com/claude/reference/streaming.
        def request_headers
          {
            "Accept" => "application/json",
            'anthropic-version' => '2023-06-01',
            'X-Gitlab-Unit-Primitive' => unit_primitive
          }.merge(Gitlab::AiGateway.headers(user: user, token: api_key))
        end

        def request_body(prompt:, options: {})
          {
            prompt: prompt,
            model: model,
            max_tokens_to_sample: DEFAULT_MAX_TOKENS,
            temperature: DEFAULT_TEMPERATURE
          }.merge(options)
        end

        def request_body_for_messages(messages:, options: {})
          {
            messages: messages,
            model: model,
            max_tokens: DEFAULT_MAX_TOKENS,
            temperature: DEFAULT_TEMPERATURE
          }.merge(options)
        end

        def token_size(content)
          # Anthropic's APIs don't send used tokens as part of the response, so
          # instead we estimate the number of tokens based on typical token size -
          # one token is roughly 4 chars.
          content.to_s.size / 4
        end

        # Following the SSE spec
        # https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation
        # and using the format from Anthropic: https://docs.anthropic.com/claude/reference/streaming#example
        # we can assume that the JSON we're looking comes after `data: `
        def parse_sse_events(fragment)
          fragment.scan(/(?:data): (\{.*\})/i).flatten.map { |data| Gitlab::Json.parse(data) }
        end

        def model
          CLAUDE_2_1
        end
      end
    end
  end
end
