# frozen_string_literal: true

module AppSec
  module ContainerScanning
    class ScanImageWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :always
      feature_category :software_composition_analysis
      deduplicate :until_executed, including_scheduled: true
      sidekiq_options retry: 3
      idempotent!

      def handle_event(event)
        ScanImageService.new(
          image: event.data.fetch(:image),
          project_id: event.data.fetch(:project_id),
          user_id: event.data.fetch(:user_id)
        ).execute
      end

      def self.dispatch?(event)
        !!(event.project&.security_setting&.container_scanning_for_registry_enabled? &&
          !event.project&.repository&.empty? &&
          event.data.fetch(:image).ends_with?(':latest'))
      end
    end
  end
end
