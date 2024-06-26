# frozen_string_literal: true

module Arkose
  class RecordUserDataService
    attr_reader :response, :user

    def initialize(response:, user:)
      @response = response
      @user = user
    end

    def execute
      return ServiceResponse.error(message: 'user is required') unless user.present?
      return ServiceResponse.error(message: 'Invalid Arkose Labs token') if response.invalid_token?

      add_or_update_arkose_attributes

      # Store risk scores as abuse trust scores
      store_risk_scores

      logger.log_risk_band_assignment

      ServiceResponse.success
    end

    private

    def add_or_update_arkose_attributes
      return if Gitlab::Database.read_only?

      UserCustomAttribute.upsert_custom_attributes(custom_attributes)
    end

    def custom_attributes
      custom_attributes = []
      custom_attributes.push({ key: 'arkose_session', value: response.session_id })
      custom_attributes.push({ key: 'arkose_device_id', value: response.device_id }) unless response.device_id.nil?
      custom_attributes.push({ key: UserCustomAttribute::ARKOSE_RISK_BAND, value: response.risk_band })
      custom_attributes.push({ key: 'arkose_global_score', value: response.global_score })
      custom_attributes.push({ key: 'arkose_custom_score', value: response.custom_score })

      custom_attributes.map! { |custom_attribute| custom_attribute.merge({ user_id: user.id }) }
      custom_attributes
    end

    def store_risk_scores
      Abuse::TrustScoreWorker.perform_async(user.id, :arkose_global_score, response.global_score.to_f)
      Abuse::TrustScoreWorker.perform_async(user.id, :arkose_custom_score, response.custom_score.to_f)
    end

    def logger
      @logger ||= ::Arkose::Logger.new(
        session_token: nil,
        user: user,
        verify_response: response
      )
    end
  end
end
