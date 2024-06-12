# frozen_string_literal: true

module AuditEvents
  module ExternallyStreamable
    extend ActiveSupport::Concern

    MAXIMUM_NAMESPACE_FILTER_COUNT = 5
    MAXIMUM_DESTINATIONS_PER_ENTITY = 5

    included do
      before_validation :assign_default_name
      before_validation :assign_default_log_id, if: :gcp?

      enum category: {
        http: 0,
        gcp: 1,
        aws: 2
      }

      validates :name, length: { maximum: 72 }
      validates :category, presence: true

      validates :config, presence: true,
        json_schema: { filename: 'audit_events_http_external_streaming_destination_config' }, if: :http?
      validates :config, presence: true,
        json_schema: { filename: 'audit_events_aws_external_streaming_destination_config' }, if: :aws?
      validates :config, presence: true,
        json_schema: { filename: 'audit_events_gcp_external_streaming_destination_config' }, if: :gcp?
      validates :secret_token, presence: true

      validates_with AuditEvents::HttpDestinationValidator, if: :http?
      validates_with AuditEvents::AwsDestinationValidator, if: :aws?
      validates_with AuditEvents::GcpDestinationValidator, if: :gcp?
      validate :no_more_than_5_namespace_filters?

      attr_encrypted :secret_token,
        mode: :per_attribute_iv,
        key: Settings.attr_encrypted_db_key_base_32,
        algorithm: 'aes-256-gcm',
        encode: false,
        encode_iv: false

      scope :configs_of_parent, ->(record_id, category) {
        where.not(id: record_id).where(category: category).limit(MAXIMUM_DESTINATIONS_PER_ENTITY).pluck(:config)
      }

      private

      def assign_default_name
        self.name ||= "Destination_#{SecureRandom.uuid}"
      end

      def no_more_than_5_namespace_filters?
        return unless namespace_filters.count > MAXIMUM_NAMESPACE_FILTER_COUNT

        errors.add(:namespace_filters,
          format(_("are limited to %{max_count} per destination"), max_count: MAXIMUM_NAMESPACE_FILTER_COUNT))
      end

      def assign_default_log_id
        config["logIdName"] = "audit-events" if config["logIdName"].blank?
      end
    end
  end
end
