# frozen_string_literal: true

module EE
  # This class is responsible for updating the namespace settings of a specific group.
  #
  module NamespaceSettings
    module UpdateService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        super

        publish_event

        unless can_update_prevent_forking?
          group.errors.add(
            :prevent_forking_outside_group,
            s_('GroupSettings|Prevent forking setting was not saved')
          )
        end

        unless can_update_service_access_tokens_expiration_enforced?
          group.errors.add(
            :service_access_tokens_expiration_enforced,
            s_('GroupSettings|Service access tokens expiration enforced setting was not saved')
          )
        end
      end

      private

      def can_update_prevent_forking?
        return true unless settings_params.key?(:prevent_forking_outside_group)

        if can?(current_user, :change_prevent_group_forking, group)
          true
        else
          settings_params.delete(:prevent_forking_outside_group)

          false
        end
      end

      def can_update_service_access_tokens_expiration_enforced?
        return true unless settings_params.key?(:service_access_tokens_expiration_enforced)

        return true if group.root? && can?(current_user, :admin_service_accounts, group)

        settings_params.delete(:service_access_tokens_expiration_enforced)
        false
      end

      def ai_settings_changed?
        ::NamespaceSettings::AiRelatedSettingsChangedEvent::AI_RELATED_SETTINGS.any? do |setting|
          group.namespace_settings.changes.key?(setting)
        end
      end

      def publish_event
        return unless ai_settings_changed?

        ::Gitlab::EventStore.publish(
          ::NamespaceSettings::AiRelatedSettingsChangedEvent.new(data: { group_id: group.id })
        )
      end
    end
  end
end
