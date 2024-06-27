# frozen_string_literal: true

module EE
  module ContainerRegistry
    module ContainerRegistryHelper
      extend ::Gitlab::Utils::Override

      override :project_container_registry_template_data
      def project_container_registry_template_data(project, connection_error, invalid_path_error)
        super.merge(
          security_configuration_path: project_security_configuration_path(project),
          container_scanning_for_registry_docs_path:
            help_page_path('user/application_security/continuous_vulnerability_scanning/index')
        )
      end
    end
  end
end
