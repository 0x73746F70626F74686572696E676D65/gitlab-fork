# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      class Configuration
        include ::API::Helpers::CloudConnector

        DEFAULT_TEMPERATURE = 0.2
        DEFAULT_MAX_OUTPUT_TOKENS = 1024
        DEFAULT_TOP_K = 40
        DEFAULT_TOP_P = 0.95

        delegate :host, :url, :payload, :as_json, to: :model_config

        def initialize(model_config:, user:, unit_primitive:)
          @model_config = model_config
          @user = user
          @unit_primitive = unit_primitive
        end

        def self.default_payload_parameters
          {
            temperature: DEFAULT_TEMPERATURE,
            maxOutputTokens: DEFAULT_MAX_OUTPUT_TOKENS,
            topK: DEFAULT_TOP_K,
            topP: DEFAULT_TOP_P
          }
        end

        def self.payload_parameters(params = {})
          default_payload_parameters.merge(params)
        end

        def access_token
          ::CloudConnector::AvailableServices.find_by_name(:vertex_ai_proxy).access_token(user)
        end

        def headers
          {
            "Accept" => "application/json",
            "Authorization" => "Bearer #{access_token}",
            "Host" => model_config.host,
            "Content-Type" => "application/json",
            'X-Gitlab-Authentication-Type' => 'oidc',
            'X-Gitlab-Unit-Primitive' => unit_primitive,
            'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id
          }.merge(cloud_connector_headers(user))
        end

        private

        attr_reader :model_config, :unit_primitive, :user
      end
    end
  end
end
