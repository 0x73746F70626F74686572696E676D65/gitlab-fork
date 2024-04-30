# frozen_string_literal: true

module Security
  module Configuration
    class SetPreReceiveSecretDetection
      def self.execute(current_user:, namespace:, enable:)
        # At present, the security_setting feature is exclusively accessible for projects.
        # Following the implementation of https://gitlab.com/gitlab-org/gitlab/-/issues/451357,
        # this feature will also be available at the group level.
        response = ServiceResponse.success(
          payload: {
            enabled: namespace.security_setting.set_pre_receive_secret_detection!(
              enabled: enable
            ),
            errors: []
          })

        if response.success?
          Audit::ProjectSecuritySettingChangesAuditor.new(
            current_user: current_user, model: namespace.security_setting).execute
        end

        response
      rescue StandardError => e
        ServiceResponse.error(
          message: e.message,
          payload: { enabled: nil }
        )
      end
    end
  end
end
