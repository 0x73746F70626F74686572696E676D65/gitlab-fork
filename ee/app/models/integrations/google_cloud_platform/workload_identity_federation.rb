# frozen_string_literal: true

module Integrations
  module GoogleCloudPlatform
    class WorkloadIdentityFederation < Integration
      include HasAvatar

      attribute :alert_events, default: false
      attribute :commit_events, default: false
      attribute :confidential_issues_events, default: false
      attribute :confidential_note_events, default: false
      attribute :issues_events, default: false
      attribute :job_events, default: false
      attribute :merge_requests_events, default: false
      attribute :note_events, default: false
      attribute :pipeline_events, default: false
      attribute :push_events, default: false
      attribute :tag_push_events, default: false
      attribute :wiki_page_events, default: false
      attribute :comment_on_event_enabled, default: false

      with_options if: :activated? do
        validates :workload_identity_federation_project_id, presence: true
        validates :workload_identity_federation_project_number, presence: true, numericality: { only_integer: true }
        validates :workload_identity_pool_id, presence: true
        validates :workload_identity_pool_provider_id, presence: true
      end

      field :workload_identity_federation_project_id,
        required: true,
        title: -> { s_('GoogleCloudPlatformService|Project ID') },
        description: -> {
          s_('GoogleCloudPlatformService|Google Cloud project ID for the Workload Identity Federation.')
        },
        help: -> {
          format(
            s_('GoogleCloudPlatformService|Example: %{code_open}my-sample-project-191923%{code_close}'),
            {
              code_open: '<code>',
              code_close: '</code>'
            }
          )
        }

      field :workload_identity_federation_project_number,
        required: true,
        title: -> { s_('GoogleCloudPlatformService|Project number') },
        description: -> {
          s_('GoogleCloudPlatformService|Google Cloud project number for the Workload Identity Federation.')
        },
        help: -> {
          format(
            s_('GoogleCloudPlatformService|Example: %{code_open}314053285323%{code_close}'),
            {
              code_open: '<code>',
              code_close: '</code>'
            }
          )
        }

      field :workload_identity_pool_id,
        required: true,
        title: -> { s_('GoogleCloudPlatformService|Pool ID') },
        description: -> { s_('GoogleCloudPlatformService|ID of the Workload Identity Pool.') }

      field :workload_identity_pool_provider_id,
        required: true,
        title: -> { s_('GoogleCloudPlatformService|Provider ID') },
        description: -> { s_('GoogleCloudPlatformService|ID of the Workload Identity Pool provider.') }

      def self.title
        s_('GoogleCloudPlatformService|Google Cloud IAM')
      end

      def self.description
        s_(
          'GoogleCloudPlatformService|' \
          'Manage permissions for Google Cloud resources with Identity and Access Management (IAM).'
        )
      end

      def self.to_param
        'google_cloud_platform_workload_identity_federation'
      end

      def self.supported_events
        []
      end

      def self.wlif_issuer_url(project)
        "#{::GoogleCloudPlatform.glgo_base_url}/oidc/#{project.root_namespace.path}"
      end

      # used when setting up WLIF pools
      # google cloud supports a max of 50 attributes
      # https://cloud.google.com/iam/docs/workload-identity-federation#mapping
      #
      # list of all possible attributes at
      # https://docs.gitlab.com/ee/ci/secrets/id_token_authentication.html#token-payload
      def self.jwt_claim_mapping
        access_attributes = Gitlab::Access.sym_options_with_owner.keys
        attribute_mapping = access_attributes.to_h do |k, _v|
          ["attribute.#{k}_access", "assertion.#{k}_access"]
        end

        additional_attributes = %w[
          namespace_id
          namespace_path
          project_id
          project_path
          user_id
          user_login
          user_email
          user_access_level
        ]
        additional_attributes.each { |a| attribute_mapping["attribute.#{a}"] = "assertion.#{a}" }

        attribute_mapping['google.subject'] = 'assertion.sub'
        attribute_mapping
      end

      def self.jwt_claim_mapping_script_value
        jwt_claim_mapping.map { |k, v| "#{k}=#{v}" }.join(',')
      end

      # We will make the integration testable in https://gitlab.com/gitlab-org/gitlab/-/issues/439885
      def testable?
        false
      end

      def identity_provider_resource_name
        return unless parent.google_cloud_support_enabled? && activated?

        "//#{identity_pool_resource_name}/providers/#{workload_identity_pool_provider_id}"
      end

      def identity_pool_resource_name
        return unless parent.google_cloud_support_enabled? && activated?

        "iam.googleapis.com/projects/#{workload_identity_federation_project_number}/" \
          "locations/global/workloadIdentityPools/#{workload_identity_pool_id}"
      end
    end
  end
end
