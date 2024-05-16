# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module ModelConfigurations
        class Base
          MissingConfigurationError = Class.new(StandardError)

          def initialize(user:)
            @user = user
          end

          def url
            raise MissingConfigurationError if host.blank? || vertex_ai_project.blank?

            if ::Feature.enabled?(:use_ai_gateway_proxy, user)
              return "#{Gitlab::AiGateway.url}/v1/proxy/vertex-ai" \
                "/v1/projects/#{vertex_ai_project}/locations/#{vertex_ai_location}" \
                "/publishers/google/models/#{model}:predict"
            end

            text_model_url = URI::HTTPS.build(
              host: host,
              path: "/v1/projects/#{vertex_ai_project}/locations/us-central1/publishers/google/models/#{model}:predict"
            )
            text_model_url.to_s
          end

          def host
            vertex_ai_host || "us-central1-aiplatform.googleapis.com"
          end

          def as_json(_opts = nil)
            {
              vertex_ai_host: host,
              vertex_ai_project: vertex_ai_project,
              model: model
            }
          end

          private

          attr_reader :user

          def vertex_ai_host
            return URI.parse(Gitlab::AiGateway.url).host if ::Feature.enabled?(:use_ai_gateway_proxy, user)

            settings.vertex_ai_host
          end

          def vertex_ai_project
            if ::Feature.enabled?(:use_ai_gateway_proxy, user)
              return "PROJECT" # AI Gateway replaces the project hence setting an arbitrary value.
            end

            settings.vertex_ai_project
          end

          def vertex_ai_location
            "LOCATION" # AI Gateway replaces the location hence setting an arbitrary value.
          end

          def settings
            @settings ||= Gitlab::CurrentSettings.current_application_settings
          end

          def model
            self.class::NAME
          end
        end
      end
    end
  end
end
