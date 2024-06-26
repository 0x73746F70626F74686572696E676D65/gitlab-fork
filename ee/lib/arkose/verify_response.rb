# frozen_string_literal: true

module Arkose
  class VerifyResponse
    attr_reader :response

    InvalidResponseFormatError = Class.new(StandardError)

    ALLOWLIST_TELLTALE = 'gitlab1-whitelist-qa-team'
    RISK_BAND_HIGH = 'High'
    RISK_BAND_MEDIUM = 'Medium'
    RISK_BAND_LOW = 'Low'
    ARKOSE_RISK_BANDS = [RISK_BAND_LOW, RISK_BAND_MEDIUM, RISK_BAND_HIGH].freeze

    def initialize(response)
      unless response.is_a? Hash
        raise InvalidResponseFormatError, "Arkose Labs Verify API returned a #{response.class} instead of of an object"
      end

      @response = response
    end

    def invalid_token?
      response&.key?('error')
    end

    def error
      response["error"]
    end

    # Arkose can opt to not show a challenge ("Transparent mode") to the user if
    # they are deemed safe. When this happens `solved` is still `true`
    # (challenge_solved? => true) even though the user didn't actually solve a
    # challenge.
    #
    # Here, we want to know if the user was shown and solved a challenge-not
    # "Transparent mode".
    def interactive_challenge_solved?
      challenge_shown? && challenge_solved?
    end

    def challenge_shown?
      suppressed = response&.dig('session_details', 'suppressed')
      suppressed.nil? ? false : !suppressed
    end

    def challenge_solved?
      solved = response&.dig('session_details', 'solved')
      solved.nil? ? true : solved
    end

    def low_risk?
      risk_band.present? ? risk_band != 'High' : true
    end

    def allowlisted?
      telltale_list = response&.dig('session_details', 'telltale_list') || []
      telltale_list.include?(ALLOWLIST_TELLTALE)
    end

    def custom_score
      response&.dig('session_risk', 'custom', 'score') || 0
    end

    def global_score
      response&.dig('session_risk', 'global', 'score') || 0
    end

    def risk_band
      response&.dig('session_risk', 'risk_band') || RISK_BAND_MEDIUM
    end

    def session_id
      response&.dig('session_details', 'session') || 'Unavailable'
    end

    def device_id
      response&.dig('session_details', 'device_id')
    end

    def risk_category
      response&.dig('session_risk', 'risk_category') || 'Unavailable'
    end

    def global_telltale_list
      response&.dig('session_risk', 'global', 'telltales') || 'Unavailable'
    end

    def custom_telltale_list
      response&.dig('session_risk', 'custom', 'telltales') || 'Unavailable'
    end

    def data_exchange_blob_received?
      response&.dig('data_exchange', 'blob_received') || false
    end

    def data_exchange_blob_decrypted?
      response&.dig('data_exchange', 'blob_decrypted') || false
    end

    def challenge_type
      response&.dig('session_details', 'challenge_type')
    end

    def session_is_legit?
      response&.dig('session_details', 'session_is_legit')
    end

    def country
      response&.dig('ip_intelligence', 'country')
    end

    def vpn?
      response&.dig('ip_intelligence', 'is_vpn')
    end

    def bot?
      response&.dig('ip_intelligence', 'is_bot')
    end
  end
end
