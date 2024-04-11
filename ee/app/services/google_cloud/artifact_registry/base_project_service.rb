# frozen_string_literal: true

module GoogleCloud
  module ArtifactRegistry
    class BaseProjectService < ::BaseProjectService
      ERROR_RESPONSES = {
        saas_only: ServiceResponse.error(message: "This is a SaaS-only feature that can't run here"),
        feature_flag_disabled: ServiceResponse.error(message: 'Feature flag not enabled'),
        access_denied: ServiceResponse.error(message: 'Access denied'),
        no_wlif_integration: ServiceResponse.error(
          message: 'Google Cloud Identity and Access Management (IAM) project integration not set'
        ),
        wlif_integration_disabled: ServiceResponse.error(
          message: 'Google Cloud Identity and Access Management (IAM) project integration not active'
        ),
        no_artifact_registry_integration: ServiceResponse.error(message: 'Artifact registry integration not set'),
        artifact_registry_integration_disabled: ServiceResponse.error(
          message: 'Artifact registry integration not active'
        ),
        authentication_error: ServiceResponse.error(message: 'Unable to authenticate against Google Cloud'),
        api_error: ServiceResponse.error(message: 'Unsuccessful Google Cloud API request')
      }.freeze

      INTEGRATION_TYPE = Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.name

      def execute
        validation_response = validate_before_execute
        return validation_response if validation_response&.error?

        handling_client_errors { call_client }
      end

      private

      def validate_before_execute
        return ERROR_RESPONSES[:saas_only] unless Gitlab::Saas.feature_available?(:google_cloud_support)

        unless Feature.enabled?(:google_cloud_support_feature_flag, project&.root_ancestor)
          return ERROR_RESPONSES[:feature_flag_disabled]
        end

        return ERROR_RESPONSES[:no_wlif_integration] unless wlif_integration.present?
        return ERROR_RESPONSES[:wlif_integration_disabled] unless wlif_integration.activated?
        return ERROR_RESPONSES[:no_artifact_registry_integration] unless artifact_registry_integration.present?
        return ERROR_RESPONSES[:artifact_registry_integration_disabled] unless artifact_registry_integration.activated?

        ERROR_RESPONSES[:access_denied] unless allowed?
      end

      def allowed?
        can?(current_user, :read_google_cloud_artifact_registry, project)
      end

      def client
        ::GoogleCloud::ArtifactRegistry::Client.new(wlif_integration: wlif_integration, user: current_user)
      end

      def wlif_integration
        project.google_cloud_platform_workload_identity_federation_integration
      end

      def artifact_registry_integration
        project.google_cloud_platform_artifact_registry_integration
      end

      def handling_client_errors
        yield
      rescue ::GoogleCloud::AuthenticationError => e
        log_error_with_project_id(message: e.message)
        ERROR_RESPONSES[:authentication_error]
      rescue ::GoogleCloud::ApiError => e
        log_error_with_project_id(message: e.message)
        ERROR_RESPONSES[:api_error]
      end

      def log_error_with_project_id(message:)
        log_error(class_name: self.class.name, project_id: project&.id, message: message)
      end
    end
  end
end
