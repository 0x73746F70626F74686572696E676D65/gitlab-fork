# frozen_string_literal: true

module EE
  module Projects
    module Security
      module ConfigurationPresenter
        extend ::Gitlab::Utils::Override

        private

        override :continuous_vulnerability_scans_enabled
        def continuous_vulnerability_scans_enabled
          project_settings&.continuous_vulnerability_scans_enabled
        end

        override :container_scanning_for_registry_enabled
        def container_scanning_for_registry_enabled
          project_settings&.container_scanning_for_registry_enabled
        end

        override :pre_receive_secret_detection_enabled
        def pre_receive_secret_detection_enabled
          project_settings&.pre_receive_secret_detection_enabled
        end
      end
    end
  end
end
