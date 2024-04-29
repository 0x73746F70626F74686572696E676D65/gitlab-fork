# frozen_string_literal: true

module AuditEvents
  module ExternallyStreamable
    extend ActiveSupport::Concern

    MAXIMUM_NAMESPACE_FILTER_COUNT = 5

    included do
      before_validation :assign_default_name

      enum category: {
        http: 0,
        gcp: 1,
        aws: 2
      }

      validates :name, length: { maximum: 72 }
      validates :category, presence: true

      validates :config, presence: true, json_schema: { filename: 'external_streaming_destination_config' }
      validates :secret_token, presence: true

      validate :no_more_than_5_namespace_filters?

      attr_encrypted :secret_token,
        mode: :per_attribute_iv,
        key: Settings.attr_encrypted_db_key_base_32,
        algorithm: 'aes-256-gcm',
        encode: false,
        encode_iv: false

      private

      def assign_default_name
        self.name ||= "Destination_#{SecureRandom.uuid}"
      end

      def no_more_than_5_namespace_filters?
        return unless namespace_filters.count > MAXIMUM_NAMESPACE_FILTER_COUNT

        errors.add(:namespace_filters,
          format(_("are limited to %{max_count} per destination"), max_count: MAXIMUM_NAMESPACE_FILTER_COUNT))
      end
    end
  end
end
