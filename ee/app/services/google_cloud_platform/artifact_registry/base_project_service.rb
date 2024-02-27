# frozen_string_literal: true

module GoogleCloudPlatform
  module ArtifactRegistry
    class BaseProjectService < ::BaseProjectService
      ERROR_RESPONSES = {
        saas_only: ServiceResponse.error(message: "This is a SaaS-only feature that can't run here"),
        feature_flag_disabled: ServiceResponse.error(message: 'Feature flag not enabled'),
        access_denied: ServiceResponse.error(message: 'Access denied'),
        no_project_integration: ServiceResponse.error(message: 'Project Artifact Registry integration not set'),
        project_integration_disabled: ServiceResponse.error(
          message: 'Project Artifact Registry integration not active'
        ),
        authentication_error: ServiceResponse.error(message: 'Unable to authenticate against Google Cloud'),
        api_error: ServiceResponse.error(message: 'Unsuccessful Google Cloud API request')
      }.freeze

      def execute
        validation_response = validate_before_execute
        return validation_response if validation_response&.error?

        handling_client_errors { call_client }
      end

      private

      delegate :artifact_registry_location, :artifact_registry_repository, to: :project_integration, private: true

      def validate_before_execute
        return ERROR_RESPONSES[:saas_only] unless Gitlab::Saas.feature_available?(:google_cloud_support)
        return ERROR_RESPONSES[:feature_flag_disabled] unless Feature.enabled?(:gcp_artifact_registry, project)
        return ERROR_RESPONSES[:no_project_integration] unless project_integration.present?
        return ERROR_RESPONSES[:project_integration_disabled] unless project_integration.active

        ERROR_RESPONSES[:access_denied] unless allowed?
      end

      def allowed?
        can?(current_user, :read_google_cloud_artifact_registry, project)
      end

      def client
        ::GoogleCloudPlatform::ArtifactRegistry::Client.new(
          project_integration: project_integration,
          user: current_user,
          artifact_registry_location: artifact_registry_location,
          artifact_registry_repository: artifact_registry_repository
        )
      end

      def project_integration
        project.google_cloud_platform_artifact_registry_integration
      end

      def handling_client_errors
        yield
      rescue ::GoogleCloudPlatform::AuthenticationError => e
        log_error_with_project_id(message: e.message)
        ERROR_RESPONSES[:authentication_error]
      rescue ::GoogleCloudPlatform::ApiError => e
        log_error_with_project_id(message: e.message)
        ERROR_RESPONSES[:api_error]
      end

      def log_error_with_project_id(message:)
        log_error(class_name: self.class.name, project_id: project&.id, message: message)
      end
    end
  end
end
