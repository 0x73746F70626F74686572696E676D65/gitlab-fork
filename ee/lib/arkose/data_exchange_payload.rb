# frozen_string_literal: true

#
# https://support.arkoselabs.com/hc/en-us/articles/4410529474323-Data-Exchange-Enhanced-Detection-and-API-Source-Validation
#

module Arkose
  class DataExchangePayload
    USE_CASE_SIGN_UP = 'SIGN_UP'
    USE_CASE_IDENTITY_VERIFICATION = 'IDENTITY_VERIFICATION'

    # Transparent mode - no challenge shown to the user. Inverse of interactive
    # mode where the user is required to solve a challenge.
    # See https://developer.arkoselabs.com/docs/verify-api-v4-response-fields
    def initialize(request, use_case:, require_challenge: false)
      @request = request
      @use_case = use_case
      @require_challenge = require_challenge
    end

    def build
      return unless shared_key

      encrypted_data
    end

    private

    attr_reader :request, :use_case, :require_challenge

    def shared_key
      @shared_key ||= Settings.data_exchange_key
    end

    def json_data
      now = Time.current.to_i

      data = {
        timestamp: now.to_s, # required to be a string
        "HEADER_user-agent" => request.user_agent,
        "HEADER_origin" => request.origin,
        "HEADER_referer" => request.referer,
        "HEADER_accept-language" => request.headers['HTTP_ACCEPT_LANGUAGE'],
        "HEADER_sec-fetch-site" => request.headers['HTTP_SEC_FETCH_SITE'],
        ip_address: request.ip,
        use_case: use_case,
        api_source_validation: {
          timestamp: now,
          token: SecureRandom.uuid
        }
      }

      # Arkose expects the value to be a string instead of a boolean
      data[:interactive] = 'true' if require_challenge

      data.compact.to_json
    end

    def encrypted_data
      cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
      cipher.key = Base64.decode64(shared_key)

      initialization_vector = cipher.random_iv
      encoded_initialization_vector = Base64.encode64(initialization_vector)

      # required when using GCM. Must come after setting key and initialization vector
      cipher.auth_data = ""

      cipher_text = cipher.update(json_data) + cipher.final

      tag = cipher.auth_tag

      encoded_cipher_text_and_tag = Base64.encode64(cipher_text + tag)

      "#{encoded_initialization_vector}.#{encoded_cipher_text_and_tag}"
    end
  end
end
