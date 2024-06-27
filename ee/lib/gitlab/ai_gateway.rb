# frozen_string_literal: true

module Gitlab
  module AiGateway
    ForbiddenError = Class.new(StandardError)

    def self.url
      ENV['AI_GATEWAY_URL'] || "#{::CloudConnector::Config.base_url}/ai"
    end

    def self.access_token_url
      base_url = ENV['AI_GATEWAY_URL'] || "#{::CloudConnector::Config.base_url}/auth"

      "#{base_url}/v1/code/user_access_token"
    end

    def self.headers(user:, token:, agent: nil)
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json',
        'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id,
        # Forward the request time to the model gateway to calculate latency
        'X-Gitlab-Rails-Send-Start' => Time.now.to_f.to_s
      }.merge(Gitlab::CloudConnector.headers(user))
        .tap do |result|
          result['User-Agent'] = agent if agent # Forward the User-Agent on to the model gateway
        end
    end
  end
end
