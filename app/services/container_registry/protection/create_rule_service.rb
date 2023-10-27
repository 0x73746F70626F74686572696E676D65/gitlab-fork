# frozen_string_literal: true

module ContainerRegistry
  module Protection
    class CreateRuleService < BaseService
      ALLOWED_ATTRIBUTES = %i[
        container_path_pattern
        push_protected_up_to_access_level
        delete_protected_up_to_access_level
      ].freeze

      def execute
        unless can?(current_user, :admin_container_image, project)
          error_message = _('Unauthorized to create a container registry protection rule')
          return service_response_error(message: error_message)
        end

        container_registry_protection_rule =
          project.container_registry_protection_rules.create(params.slice(*ALLOWED_ATTRIBUTES))

        unless container_registry_protection_rule.persisted?
          return service_response_error(message: container_registry_protection_rule.errors.full_messages.to_sentence)
        end

        ServiceResponse.success(payload: { container_registry_protection_rule: container_registry_protection_rule })
      rescue StandardError => e
        service_response_error(message: e.message)
      end

      private

      def service_response_error(message:)
        ServiceResponse.error(
          message: message,
          payload: { container_registry_protection_rule: nil }
        )
      end
    end
  end
end
