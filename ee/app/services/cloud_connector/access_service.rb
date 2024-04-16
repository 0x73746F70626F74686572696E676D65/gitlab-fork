# frozen_string_literal: true

module CloudConnector
  class AccessService
    include ::Gitlab::Utils::StrongMemoize

    # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- we don't have dedicated SM/.com Cloud Connector features
    # or other checks that would allow us to identify where the code is running. We rely on instance checks for now.
    # Will be addressed in https://gitlab.com/gitlab-org/gitlab/-/issues/437725
    #
    # audience:
    #   The JWT aud claim used for GitLab.com tokens (ignored on self-managed)
    # scopes:
    #   The JWT scopes claim used for GitLab.com tokens (ignored on self-managed)
    # extra_claims:
    #   Custom JWT claims used for GitLab.com tokens (ignored on self-managed)
    def access_token(audience:, scopes:, extra_claims: {})
      Gitlab.org_or_com? ? saas_token(audience, scopes, extra_claims) : self_managed_token
    end

    # We allow free usage of cloud connected feature on Self-Managed if:
    # 1) the cut off date is empty,
    # 2) or the cut off date is set in the future
    def free_access_for?(service_name)
      return false if Gitlab.org_or_com? # Safety check. This method should only be called on SM.

      !!available_services[service_name]&.free_access?
    end
    # rubocop:enable Gitlab/AvoidGitlabInstanceChecks

    def available_services
      service_descriptors = access_record&.data&.[]("available_services") || []
      service_descriptors.map { |descriptor| build_connected_service(descriptor) }.index_by(&:name)
    end
    strong_memoize_attr :available_services

    private

    def self_managed_token
      ::CloudConnector::ServiceAccessToken.active.last&.token
    end

    def saas_token(audience, scopes, extra_claims)
      Gitlab::CloudConnector::SelfIssuedToken.new(
        audience: audience,
        subject: Gitlab::CurrentSettings.uuid,
        scopes: scopes,
        extra_claims: extra_claims
      ).encoded
    end

    def access_record
      ::CloudConnector::Access.last
    end

    def build_connected_service(service_descriptor)
      CloudConnector::ConnectedService.new(
        name: service_descriptor["name"].to_sym,
        cut_off_date: Time.zone.parse(service_descriptor["serviceStartTime"].to_s)
      )
    end
  end
end
