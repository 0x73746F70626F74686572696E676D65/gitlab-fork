# frozen_string_literal: true

module Gitlab
  module AiGateway
    def self.url
      ENV['AI_GATEWAY_URL'] || "#{::CloudConnector::Config.base_url}/ai"
    end

    def self.access_token_url
      base_url = ENV['AI_GATEWAY_URL'] || "#{::CloudConnector::Config.base_url}/auth"

      "#{base_url}/v1/code/user_access_token"
    end
  end
end
