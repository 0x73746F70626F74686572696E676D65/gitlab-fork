# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class DocsClient
        include ::Gitlab::Llm::Concerns::ExponentialBackoff
        include ::Gitlab::Llm::Concerns::EventTracking
        include ::Gitlab::Utils::StrongMemoize

        DEFAULT_TIMEOUT = 30.seconds
        DEFAULT_TYPE = 'search-docs'
        DEFAULT_SOURCE = 'GitLab EE'

        def initialize(user, tracking_context: {})
          @user = user
          @tracking_context = tracking_context
          @logger = Gitlab::Llm::Logger.build
        end

        def search(query:, **options)
          return unless enabled?

          perform_search_request(query: query, options: options)
        end

        private

        attr_reader :user, :logger, :tracking_context

        def perform_search_request(query:, options:)
          logger.info(message: "Searching docs from AI Gateway", options: options)
          timeout = options.delete(:timeout) || DEFAULT_TIMEOUT

          response = Gitlab::HTTP.post(
            "#{Gitlab::AiGateway.url}/v1/search/gitlab-docs",
            headers: Gitlab::AiGateway.headers(user: user, token: access_token),
            body: request_body(query: query).to_json,
            timeout: timeout,
            allow_local_requests: true
          )

          logger.info_or_debug(user, message: "Searched docs from AI Gateway", response: response)

          response
        end

        def enabled?
          access_token.present?
        end

        def access_token
          chat_feature_setting = ::Ai::FeatureSetting.find_by_feature(:duo_chat)
          feature_name = chat_feature_setting&.self_hosted? ? :self_hosted_models : :duo_chat

          ::CloudConnector::AvailableServices.find_by_name(feature_name).access_token(user)
        end
        strong_memoize_attr :access_token

        def request_body(query:)
          {
            type: DEFAULT_TYPE,
            metadata: {
              source: DEFAULT_SOURCE,
              version: Gitlab.version_info.to_s
            },
            payload: {
              query: query
            }
          }
        end
      end
    end
  end
end
