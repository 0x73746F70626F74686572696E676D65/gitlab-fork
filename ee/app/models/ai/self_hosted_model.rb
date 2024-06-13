# frozen_string_literal: true

module Ai
  class SelfHostedModel < ApplicationRecord
    self.table_name = "ai_self_hosted_models"

    # The set of AI features is controlled by:
    #
    # - For SM that are using Cloud Connector: by CDot
    # - For GitLab.com and SM that are using self-hosted AI Gateway: by ee/config/cloud_connector/access_data.yml file
    #
    # Unlike for GitLab.com, we cannot control the availability of the features for offline SM customers if
    # they do not upgrade regularly. This is why we introduce a cut-off date to make the features unavailable if the
    # customers do not upgrade.
    CUTOFF_DATE = Date.new(2024, 8, 31)

    validates :model, presence: true
    validates :endpoint, presence: true, addressable_url: true
    validates :name, presence: true, uniqueness: true

    has_many :feature_settings

    attr_encrypted :api_token,
      mode: :per_attribute_iv,
      key: Settings.attr_encrypted_db_key_base_32,
      algorithm: 'aes-256-gcm',
      encode: true

    enum model: { mistral: 0, mixtral: 1, codegemma: 2 }
  end
end
