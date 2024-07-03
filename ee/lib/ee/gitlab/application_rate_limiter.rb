# frozen_string_literal: true

module EE
  module Gitlab
    module ApplicationRateLimiter
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :rate_limits
        def rate_limits
          super.merge({
            unique_project_downloads_for_application: {
              threshold: -> { application_settings.max_number_of_repository_downloads },
              interval: -> { application_settings.max_number_of_repository_downloads_within_time_period }
            },
            # actual values will get sent by Abuse::GitAbuse::NamespaceThrottleService
            unique_project_downloads_for_namespace: {
              threshold: 0,
              interval: 0
            },
            credit_card_verification_check_for_reuse: { threshold: 10, interval: 1.hour },
            code_suggestions_api_endpoint: { threshold: 60, interval: 1.minute },
            code_suggestions_direct_access: { threshold: 50, interval: 1.minute },
            code_suggestions_x_ray_scan: { threshold: 60, interval: 1.minute },
            code_suggestions_x_ray_dependencies: { threshold: 60, interval: 1.minute },
            soft_phone_verification_transactions_limit: { threshold: 16_000, interval: 1.day },
            hard_phone_verification_transactions_limit: { threshold: 20_000, interval: 1.day },
            container_scanning_for_registry_scans: { threshold: 50, interval: 1.day }
          }).freeze
        end
      end
    end
  end
end
