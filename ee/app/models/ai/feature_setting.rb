# frozen_string_literal: true

module Ai
  class FeatureSetting < ApplicationRecord
    self.table_name = "ai_feature_settings"

    PROVIDER_TITLES = HashWithIndifferentAccess.new({
      disabled: 'Disabled',
      vendored: 'GitLab AI Vendor',
      self_hosted: 'Self-Hosted Model'
    }).freeze

    belongs_to :self_hosted_model, foreign_key: :ai_self_hosted_model_id, inverse_of: :feature_settings

    validates :self_hosted_model, presence: true, if: :self_hosted?
    validates :feature, presence: true, uniqueness: true
    validates :provider, presence: true

    enum provider: {
      disabled: 0,
      vendored: 1,
      self_hosted: 2
    }, _default: :vendored

    enum feature: {
      code_generations: 0,
      code_completions: 1
    }

    def provider_title
      title = PROVIDER_TITLES[provider]
      return title unless self_hosted?

      "#{title} (#{self_hosted_model.model.titleize})"
    end
  end
end
