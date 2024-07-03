# frozen_string_literal: true

module EE
  module Types
    module GroupType
      extend ActiveSupport::Concern

      prepended do
        %i[epics].each do |feature|
          field "#{feature}_enabled", GraphQL::Types::Boolean,
            null: true,
            description: "Indicates if #{feature.to_s.humanize} are enabled for namespace"

          define_method "#{feature}_enabled" do
            object.feature_available?(feature)
          end
        end

        field :epic, ::Types::EpicType,
          null: true, description: 'Find a single epic.',
          resolver: ::Resolvers::EpicsResolver.single

        field :epics, ::Types::EpicType.connection_type,
          null: true, description: 'Find epics.',
          extras: [:lookahead],
          resolver: ::Resolvers::EpicsResolver

        field :epic_board, ::Types::Boards::EpicBoardType,
          null: true, description: 'Find a single epic board.',
          resolver: ::Resolvers::Boards::EpicBoardsResolver.single

        field :epic_boards, ::Types::Boards::EpicBoardType.connection_type,
          null: true,
          description: 'Find epic boards.', resolver: ::Resolvers::Boards::EpicBoardsResolver

        field :iterations, ::Types::IterationType.connection_type,
          null: true, description: 'Find iterations.',
          resolver: ::Resolvers::IterationsResolver

        field :iteration_cadences, ::Types::Iterations::CadenceType.connection_type,
          null: true,
          description: 'Find iteration cadences.',
          resolver: ::Resolvers::Iterations::CadencesResolver

        field :ci_queueing_history,
          ::Types::Ci::QueueingHistoryType,
          null: true,
          alpha: { milestone: '16.11' },
          description: "Time taken for CI jobs to be picked up by this group's runners by percentile. " \
                       "Available to users with Maintainer role for the group.",
          resolver: ::Resolvers::Ci::GroupQueueingHistoryResolver,
          extras: [:lookahead]

        field :runner_cloud_provisioning,
          ::Types::Ci::RunnerCloudProvisioningType,
          null: true,
          alpha: { milestone: '16.10' },
          description: 'Information used for provisioning the runner on a cloud provider. ' \
                       'Returns `null` if the GitLab instance is not a SaaS instance.' do
          argument :provider, ::Types::Ci::RunnerCloudProviderEnum, required: true,
            description: 'Identifier of the cloud provider.'
          argument :cloud_project_id, ::Types::GoogleCloud::ProjectType, required: true,
            description: 'Identifier of the cloud project.'
        end

        field :vulnerabilities, ::Types::VulnerabilityType.connection_type,
          null: true,
          extras: [:lookahead],
          description: 'Vulnerabilities reported on the projects in the group and its subgroups.',
          resolver: ::Resolvers::VulnerabilitiesResolver

        field :vulnerability_scanners, ::Types::VulnerabilityScannerType.connection_type,
          null: true,
          description: 'Vulnerability scanners reported on the project vulnerabilities of the group and ' \
                       'its subgroups.',
          resolver: ::Resolvers::Vulnerabilities::ScannersResolver

        field :vulnerability_severities_count, ::Types::VulnerabilitySeveritiesCountType,
          null: true,
          description: 'Counts for each vulnerability severity in the group and its subgroups.',
          resolver: ::Resolvers::VulnerabilitySeveritiesCountResolver

        field :vulnerabilities_count_by_day, ::Types::VulnerabilitiesCountByDayType.connection_type,
          null: true,
          description: 'The historical number of vulnerabilities per day for the projects in the group and ' \
                       'its subgroups.',
          resolver: ::Resolvers::VulnerabilitiesCountPerDayResolver

        field :vulnerability_grades, [::Types::VulnerableProjectsByGradeType],
          null: true,
          description: 'Represents vulnerable project counts for each grade.',
          resolver: ::Resolvers::VulnerabilitiesGradeResolver

        field :code_coverage_activities, ::Types::Ci::CodeCoverageActivityType.connection_type,
          null: true,
          description: 'Represents the code coverage activity for this group.',
          resolver: ::Resolvers::Ci::CodeCoverageActivitiesResolver

        field :stats, ::Types::GroupStatsType,
          null: true,
          description: 'Group statistics.',
          method: :itself

        field :billable_members_count, ::GraphQL::Types::Int,
          null: true,
          authorize: :owner_access,
          description: 'Number of billable users in the group.' do
            argument :requested_hosted_plan, String,
              required: false,
              description: 'Plan from which to get billable members.'
          end

        field :dora, ::Types::DoraType,
          null: true,
          method: :itself,
          description: "Group's DORA metrics."

        field :dora_performance_score_counts, ::Types::Dora::PerformanceScoreCountType.connection_type,
          null: true,
          resolver: ::Resolvers::Dora::PerformanceScoresCountResolver, complexity: 10,
          description: "Group's DORA scores for all projects by DORA key metric for the last complete month."

        field :external_audit_event_destinations,
          ::Types::AuditEvents::ExternalAuditEventDestinationType.connection_type,
          null: true,
          description: 'External locations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events

        field :external_audit_event_streaming_destinations,
          ::Types::AuditEvents::Group::StreamingDestinationType.connection_type,
          null: true,
          description: 'External destinations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events,
          alpha: { milestone: '16.11' }

        field :google_cloud_logging_configurations,
          ::Types::AuditEvents::GoogleCloudLoggingConfigurationType.connection_type,
          null: true,
          description: 'Google Cloud logging configurations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events

        field :merge_request_violations,
          ::Types::ComplianceManagement::MergeRequests::ComplianceViolationType.connection_type,
          null: true,
          description: 'Compliance violations reported on merge requests merged within the group.',
          resolver: ::Resolvers::ComplianceManagement::MergeRequests::ComplianceViolationResolver,
          authorize: :read_group_compliance_violations_report

        field :allow_stale_runner_pruning,
          ::GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether to regularly prune stale group runners. Defaults to false.',
          method: :allow_stale_runner_pruning?

        field :cluster_agents,
          ::Types::Clusters::AgentType.connection_type,
          extras: [:lookahead],
          null: true,
          description: 'Cluster agents associated with projects in the group and its subgroups.',
          resolver: ::Resolvers::Clusters::AgentsResolver

        field :enforce_free_user_cap,
          ::GraphQL::Types::Boolean,
          null: true,
          authorize: :owner_access,
          description: 'Indicates whether the group has limited users for a free plan.',
          method: :enforce_free_user_cap?

        field :gitlab_subscriptions_preview_billable_user_change,
          ::Types::GitlabSubscriptions::PreviewBillableUserChangeType,
          null: true,
          complexity: 100,
          description: 'Preview Billable User Changes',
          resolver: ::Resolvers::GitlabSubscriptions::PreviewBillableUserChangeResolver

        field :contributions,
          ::Types::Analytics::ContributionAnalytics::ContributionMetadataType.connection_type,
          null: true,
          resolver: ::Resolvers::Analytics::ContributionAnalytics::ContributionsResolver,
          description: 'Provides the aggregated contributions by users within the group and its subgroups',
          authorize: :read_group_contribution_analytics,
          connection_extension: ::Gitlab::Graphql::Extensions::ForwardOnlyExternallyPaginatedArrayExtension

        field :flow_metrics,
          ::Types::Analytics::CycleAnalytics::FlowMetrics[:group],
          null: true,
          description: 'Flow metrics for value stream analytics.',
          method: :itself,
          authorize: :read_cycle_analytics,
          alpha: { milestone: '15.10' }

        field :ai_metrics,
          ::Types::Analytics::AiMetrics,
          null: true,
          description: 'AI-related metrics.',
          resolver: ::Resolvers::Analytics::AiMetricsResolver,
          alpha: { milestone: '16.11' }

        field :project_compliance_standards_adherence,
          ::Types::Projects::ComplianceStandards::AdherenceType.connection_type,
          null: true,
          description: 'Compliance standards adherence for the projects in a group and its subgroups.',
          resolver: ::Resolvers::Projects::ComplianceStandards::AdherenceResolver,
          authorize: :read_group_compliance_adherence_report

        field :value_stream_dashboard_usage_overview,
          ::Types::Analytics::ValueStreamDashboard::CountType,
          null: true,
          resolver: ::Resolvers::Analytics::ValueStreamDashboard::CountResolver,
          description: 'Aggregated usage counts within the group',
          authorize: :read_group_analytics_dashboards,
          alpha: { milestone: '16.4' }

        field :customizable_dashboards,
          ::Types::ProductAnalytics::DashboardType.connection_type,
          description: 'Customizable dashboards for the group.',
          null: true,
          calls_gitaly: true,
          resolver: ::Resolvers::ProductAnalytics::DashboardsResolver

        field :customizable_dashboard_visualizations, ::Types::ProductAnalytics::VisualizationType.connection_type,
          description: 'Visualizations of the group or associated configuration project.',
          null: true,
          calls_gitaly: true,
          resolver: ::Resolvers::ProductAnalytics::VisualizationsResolver

        field :amazon_s3_configurations,
          ::Types::AuditEvents::AmazonS3ConfigurationType.connection_type,
          null: true,
          description: 'Amazon S3 configurations that receive audit events belonging to the group.',
          authorize: :admin_external_audit_events

        field :member_roles, ::Types::MemberRoles::MemberRoleType.connection_type,
          null: true, description: 'Member roles available for the group.',
          resolver: ::Resolvers::MemberRoles::RolesResolver,
          alpha: { milestone: '16.5' }

        field :pending_members,
          ::Types::PendingGroupMemberType.connection_type,
          null: true,
          description: 'A pending membership of a user within this group.',
          resolver: Resolvers::PendingGroupMembersResolver,
          alpha: { milestone: '16.6' }

        field :value_streams,
          description: 'Value streams available to the group.',
          null: true,
          resolver: ::Resolvers::Analytics::CycleAnalytics::ValueStreamsResolver

        field :saved_replies,
          ::Types::Groups::SavedReplyType.connection_type,
          null: true,
          resolver: ::Resolvers::Groups::SavedRepliesResolver,
          description: 'Saved replies available to the group. Available only when feature flag ' \
                       '`group_saved_replies_flag` is enabled. This field can only be resolved ' \
                       'for one group in any single request.',
          alpha: { milestone: '16.10' }

        field :saved_reply,
          resolver: ::Resolvers::Groups::SavedReplyResolver,
          description: 'Saved reply in the group. Available only when feature flag ' \
                       '`group_saved_replies_flag` is enabled. This field can only ' \
                       'be resolved for one group in any single request.',
          alpha: { milestone: '16.10' }

        field :value_stream_analytics,
          ::Types::Analytics::ValueStreamAnalyticsType,
          description: 'Information about Value Stream Analytics within the group.',
          null: true,
          resolver_method: :object

        field :security_policy_project_suggestions,
          ::Types::ProjectType.connection_type,
          null: true,
          description: 'Security policy project suggestions',
          resolver: ::Resolvers::SecurityOrchestration::SecurityPolicyProjectSuggestionsResolver

        field :duo_features_enabled, GraphQL::Types::Boolean,
          alpha: { milestone: '16.10' },
          description: 'Indicates whether GitLab Duo features are enabled for the group.'

        field :lock_duo_features_enabled, GraphQL::Types::Boolean,
          alpha: { milestone: '16.10' },
          description: 'Indicates if the GitLab Duo features enabled setting is enforced for all subgroups.'

        field :marked_for_deletion_on, ::Types::TimeType,
          null: true,
          description: 'Date when group was scheduled to be deleted.',
          alpha: { milestone: '16.11' }

        field :is_adjourned_deletion_enabled, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates if delayed group deletion is enabled.',
          method: :adjourned_deletion?,
          alpha: { milestone: '16.11' }

        field :permanent_deletion_date, GraphQL::Types::String,
          null: true,
          description: 'Date when group will be deleted if delayed group deletion is enabled.',
          alpha: { milestone: '16.11' }

        def billable_members_count(requested_hosted_plan: nil)
          object.billable_members_count(requested_hosted_plan)
        end

        def runner_cloud_provisioning(provider:, cloud_project_id:)
          {
            container: object,
            provider: provider,
            cloud_project_id: cloud_project_id
          }
        end

        def marked_for_deletion_on
          return unless group.adjourned_deletion?

          group.marked_for_deletion_on
        end

        def permanent_deletion_date
          return unless group.adjourned_deletion?

          group.permanent_deletion_date(Time.now.utc).strftime('%F')
        end
      end
    end
  end
end
