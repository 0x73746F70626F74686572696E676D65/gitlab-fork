# frozen_string_literal: true

module EE
  module Types
    module QueryType
      extend ActiveSupport::Concern
      prepended do
        field :add_on_purchase,
          ::Types::GitlabSubscriptions::AddOnPurchaseType,
          null: true,
          description: 'Retrieve the active add-on purchase. ' \
                       'This query can be used in GitLab SaaS and self-managed environments.',
          resolver: ::Resolvers::GitlabSubscriptions::AddOnPurchaseResolver
        field :ci_minutes_usage, ::Types::Ci::Minutes::NamespaceMonthlyUsageType.connection_type,
          null: true,
          description: 'Compute usage data for a namespace.' do
          argument :namespace_id, ::Types::GlobalIDType[::Namespace],
            required: false,
            description: 'Global ID of the Namespace for the monthly compute usage.'
          argument :date, ::Types::DateType,
            required: false,
            description: 'Date for which to retrieve the usage data, should be the first day of a month.'
        end
        field :current_license, ::Types::Admin::CloudLicenses::CurrentLicenseType,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::CurrentLicenseResolver,
          description: 'Fields related to the current license.'
        field :devops_adoption_enabled_namespaces,
          null: true,
          description: 'Get configured DevOps adoption namespaces. **Status:** Beta. This endpoint is subject to ' \
                       'change without notice.',
          resolver: ::Resolvers::Analytics::DevopsAdoption::EnabledNamespacesResolver
        field :epic_board_list, ::Types::Boards::EpicListType,
          null: true,
          resolver: ::Resolvers::Boards::EpicListResolver
        field :explain_vulnerability_prompt,
          ::Types::Ai::Prompt::ExplainVulnerabilityPromptType,
          null: true,
          calls_gitaly: true,
          alpha: { milestone: '16.2' },
          description: "GitLab Duo Vulnerability explanation prompt for a specified vulnerability",
          resolver: ::Resolvers::Ai::ExplainVulnerabilityPromptResolver
        field :geo_node, ::Types::Geo::GeoNodeType,
          null: true,
          resolver: ::Resolvers::Geo::GeoNodeResolver,
          description: 'Find a Geo node.'
        field :iteration, ::Types::IterationType,
          null: true,
          description: 'Find an iteration.' do
          argument :id, ::Types::GlobalIDType[::Iteration],
            required: true,
            description: 'Find an iteration by its ID.'
        end
        field :instance_security_dashboard, ::Types::InstanceSecurityDashboardType,
          null: true,
          resolver: ::Resolvers::InstanceSecurityDashboardResolver,
          description: 'Fields related to Instance Security Dashboard.'
        field :license_history_entries, ::Types::Admin::CloudLicenses::LicenseHistoryEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::LicenseHistoryEntriesResolver,
          description: 'Fields related to entries in the license history.'
        field :subscription_future_entries, ::Types::Admin::CloudLicenses::SubscriptionFutureEntryType.connection_type,
          null: true,
          resolver: ::Resolvers::Admin::CloudLicenses::SubscriptionFutureEntriesResolver,
          description: 'Fields related to entries in future subscriptions.'
        field :vulnerabilities,
          ::Types::VulnerabilityType.connection_type,
          null: true,
          extras: [:lookahead],
          description: "Vulnerabilities reported on projects on the current user's instance security dashboard.",
          resolver: ::Resolvers::VulnerabilitiesResolver
        field :vulnerabilities_count_by_day,
          ::Types::VulnerabilitiesCountByDayType.connection_type,
          null: true,
          resolver: ::Resolvers::VulnerabilitiesCountPerDayResolver,
          description: "The historical number of vulnerabilities per day for the projects on the current " \
                       "user's instance security dashboard."
        field :vulnerability,
          ::Types::VulnerabilityType,
          null: true,
          description: "Find a vulnerability." do
          argument :id, ::Types::GlobalIDType[::Vulnerability],
            required: true,
            description: 'Global ID of the Vulnerability.'
        end
        field :workspace, ::Types::RemoteDevelopment::WorkspaceType,
          null: true,
          description: 'Find a workspace.' do
          argument :id, ::Types::GlobalIDType[::RemoteDevelopment::Workspace],
            required: true,
            description: 'Find a workspace by its ID.'
        end
        field :workspaces,
          ::Types::RemoteDevelopment::WorkspaceType.connection_type,
          null: true,
          resolver: ::Resolvers::RemoteDevelopment::WorkspacesForQueryRootResolver,
          description: 'Find workspaces across the entire instance. This field is only available to instance admins, ' \
                       'it will return an empty result for all non-admins.'
        field :instance_external_audit_event_destinations,
          ::Types::AuditEvents::InstanceExternalAuditEventDestinationType.connection_type,
          null: true,
          description: 'Instance level external audit event destinations.',
          resolver: ::Resolvers::AuditEvents::InstanceExternalAuditEventDestinationsResolver

        field :ai_messages, ::Types::Ai::MessageType.connection_type,
          resolver: ::Resolvers::Ai::ChatMessagesResolver,
          alpha: { milestone: '16.1' },
          description: 'Find GitLab Duo Chat messages.'

        field :ci_queueing_history,
          ::Types::Ci::QueueingHistoryType,
          null: true,
          alpha: { milestone: '16.4' },
          description: 'Time taken for CI jobs to be picked up by runner by percentile.',
          resolver: ::Resolvers::Ci::InstanceQueueingHistoryResolver,
          extras: [:lookahead]
        field :runner_usage_by_project,
          [::Types::Ci::RunnerUsageByProjectType],
          null: true,
          alpha: { milestone: '16.9' },
          description: 'Runner usage by project.',
          resolver: ::Resolvers::Ci::RunnerUsageByProjectResolver
        field :runner_usage,
          [::Types::Ci::RunnerUsageType],
          null: true,
          alpha: { milestone: '16.9' },
          description: 'Runner usage by runner.',
          resolver: ::Resolvers::Ci::RunnerUsageResolver

        field :instance_google_cloud_logging_configurations,
          ::Types::AuditEvents::Instance::GoogleCloudLoggingConfigurationType.connection_type,
          null: true,
          description: 'Instance level google cloud logging configurations.',
          resolver: ::Resolvers::AuditEvents::Instance::GoogleCloudLoggingConfigurationsResolver
        field :member_role_permissions,
          ::Types::MemberRoles::CustomizablePermissionType.connection_type,
          null: true,
          description: 'List of all customizable permissions.',
          alpha: { milestone: '16.4' }
        field :member_role, ::Types::MemberRoles::MemberRoleType,
          null: true, description: 'Finds a single custom role.',
          resolver: ::Resolvers::MemberRoles::RolesResolver.single,
          alpha: { milestone: '16.6' }
        field :self_managed_add_on_eligible_users,
          ::Types::GitlabSubscriptions::AddOnUserType.connection_type,
          null: true,
          description: 'Users within the self-managed instance who are eligible for add-ons.',
          resolver: ::Resolvers::GitlabSubscriptions::SelfManaged::AddOnEligibleUsersResolver,
          alpha: { milestone: '16.7' }
        field :self_managed_users_queued_for_role_promotion,
          EE::Types::GitlabSubscriptions::MemberManagement::UsersQueuedForRolePromotionType.connection_type,
          null: true,
          alpha: { milestone: '17.1' },
          resolver: ::Resolvers::GitlabSubscriptions::MemberManagement::SelfManaged::
              UsersQueuedForRolePromotionResolver,
          description: 'Fields related to users within a self-managed instance that are pending role ' \
                       'promotion approval.'
        field :audit_events_instance_amazon_s3_configurations,
          ::Types::AuditEvents::Instance::AmazonS3ConfigurationType.connection_type,
          null: true,
          description: 'Instance-level Amazon S3 configurations for audit events.',
          resolver: ::Resolvers::AuditEvents::Instance::AmazonS3ConfigurationsResolver
        field :member_roles, ::Types::MemberRoles::MemberRoleType.connection_type,
          null: true, description: 'Member roles available for the instance.',
          resolver: ::Resolvers::MemberRoles::RolesResolver,
          alpha: { milestone: '16.7' }
        field :google_cloud_artifact_registry_repository_artifact,
          ::Types::GoogleCloud::ArtifactRegistry::ArtifactDetailsType,
          null: true,
          description: 'Details about an artifact in the Google Artifact Registry.',
          resolver: ::Resolvers::GoogleCloud::ArtifactRegistry::ArtifactResolver,
          alpha: { milestone: '16.10' }
        field :audit_events_instance_streaming_destinations,
          ::Types::AuditEvents::Instance::StreamingDestinationType.connection_type,
          null: true,
          description: 'Instance-level external audit event streaming destinations.',
          resolver: ::Resolvers::AuditEvents::Instance::StreamingDestinationsResolver,
          alpha: { milestone: '16.11' }

        field :ai_self_hosted_models,
          ::Types::Ai::SelfHostedModels::SelfHostedModelType.connection_type,
          null: true,
          description: 'List of Self-Hosted LLM servers.',
          resolver: ::Resolvers::Ai::SelfHostedModels::SelfHostedModelsResolver,
          alpha: { milestone: '17.1' }
      end

      def vulnerability(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def iteration(id:)
        ::GitlabSchema.find_by_gid(id)
      end

      def workspace(id:)
        unless License.feature_available?(:remote_development)
          # NOTE: Could have `included Gitlab::Graphql::Authorize::AuthorizeResource` and then use
          #       raise_resource_not_available_error!, but didn't want to take the risk to mix that into
          #       the root query type
          # rubocop:disable Graphql/ResourceNotAvailableError -- intentionally not used - see note above
          raise ::Gitlab::Graphql::Errors::ResourceNotAvailable,
            "'remote_development' licensed feature is not available"
          # rubocop:enable Graphql/ResourceNotAvailableError
        end

        ::GitlabSchema.find_by_gid(id)
      end

      def ci_minutes_usage(namespace_id: nil, date: nil)
        root_namespace = find_root_namespace(namespace_id)
        if date
          ::Ci::Minutes::NamespaceMonthlyUsage.by_namespace_and_date(root_namespace, date)
        else
          ::Ci::Minutes::NamespaceMonthlyUsage.for_namespace(root_namespace)
        end
      end

      def member_role_permissions
        MemberRole.all_customizable_permissions.keys.filter do |permission|
          ::MemberRole.permission_enabled?(permission, current_user)
        end
      end

      private

      def find_root_namespace(namespace_id)
        return current_user&.namespace unless namespace_id

        namespace = ::Gitlab::Graphql::Lazy.force(::GitlabSchema.find_by_gid(namespace_id))
        return unless namespace&.root?

        namespace
      end
    end
  end
end
