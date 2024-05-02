# frozen_string_literal: true

module EE
  module Types
    module NamespaceType
      extend ActiveSupport::Concern

      prepended do
        field :add_on_eligible_users,
          ::Types::GitlabSubscriptions::AddOnUserType.connection_type,
          null: true,
          description: 'Users in the namespace hierarchy that add ons are applicable for. This only applies to ' \
                       'root namespaces.',
          resolver: ::Resolvers::GitlabSubscriptions::AddOnEligibleUsersResolver,
          alpha: { milestone: '16.5' }

        field :add_on_purchase,
          ::Types::GitlabSubscriptions::AddOnPurchaseType,
          null: true,
          description: 'AddOnPurchase associated with the namespace',
          resolver: ::Resolvers::GitlabSubscriptions::Namespaces::AddOnPurchaseResolver,
          authorize: :read_namespace_via_membership

        field :additional_purchased_storage_size,
          GraphQL::Types::Float,
          null: true,
          description: 'Additional storage purchased for the root namespace in bytes.',
          authorize: :read_namespace_via_membership

        field :total_repository_size_excess,
          GraphQL::Types::Float,
          null: true,
          description: 'Total excess repository size of all projects in the root namespace in bytes. ' \
                       'This only applies to namespaces under Project limit enforcement.',
          authorize: :read_namespace_via_membership

        field :total_repository_size,
          GraphQL::Types::Float,
          null: true,
          description: 'Total repository size of all projects in the root namespace in bytes.',
          authorize: :read_namespace_via_membership

        field :contains_locked_projects,
          GraphQL::Types::Boolean,
          null: true,
          description: 'Includes at least one project where the repository size exceeds the limit. ' \
                       'This only applies to namespaces under Project limit enforcement.',
          method: :contains_locked_projects?,
          authorize: :read_namespace_via_membership

        field :repository_size_excess_project_count,
          GraphQL::Types::Int,
          null: true,
          description: 'Number of projects in the root namespace where the repository size exceeds the limit. ' \
                       'This only applies to namespaces under Project limit enforcement.',
          authorize: :read_namespace_via_membership

        field :actual_repository_size_limit,
          GraphQL::Types::Float,
          null: true,
          description: 'Size limit for repositories in the namespace in bytes. ' \
                       'This limit only applies to namespaces under Project limit enforcement.',
          authorize: :read_namespace_via_membership

        field :actual_size_limit,
          GraphQL::Types::Float,
          null: true,
          description: 'The actual storage size limit (in bytes) based on the enforcement type ' \
                       'of either repository or namespace. This limit is agnostic of enforcement type.',
          authorize: :read_namespace_via_membership

        field :storage_size_limit,
          GraphQL::Types::Float,
          null: true,
          description: 'The storage limit (in bytes) included with the root namespace plan. ' \
                       'This limit only applies to namespaces under namespace limit enforcement.',
          authorize: :read_namespace_via_membership

        field :is_temporary_storage_increase_enabled,
          GraphQL::Types::Boolean,
          null: true,
          description: 'Status of the temporary storage increase.',
          deprecated: {
            reason: 'Feature removal, will be completely removed in 17.0',
            milestone: '16.7'
          },
          method: :temporary_storage_increase_enabled?,
          authorize: :read_namespace_via_membership

        field :temporary_storage_increase_ends_on,
          ::Types::TimeType,
          null: true,
          description: 'Date until the temporary storage increase is active.',
          deprecated: {
            reason: 'Feature removal, will be completely removed in 17.0',
            milestone: '16.7'
          },
          authorize: :read_namespace_via_membership

        field :compliance_frameworks,
          ::Types::ComplianceManagement::ComplianceFrameworkType.connection_type,
          null: true,
          description: 'Compliance frameworks available to projects in this namespace.',
          resolver: ::Resolvers::ComplianceManagement::FrameworkResolver,
          authorize: :read_namespace_via_membership

        field :pipeline_execution_policies,
          ::Types::SecurityOrchestration::PipelineExecutionPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'Pipeline Execution Policies of the namespace.',
          resolver: ::Resolvers::SecurityOrchestration::PipelineExecutionPolicyResolver

        field :scan_execution_policies,
          ::Types::SecurityOrchestration::ScanExecutionPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'Scan Execution Policies of the namespace.',
          resolver: ::Resolvers::SecurityOrchestration::ScanExecutionPolicyResolver

        field :scan_result_policies,
          ::Types::SecurityOrchestration::ScanResultPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          deprecated: { reason: 'Use `approvalPolicies`', milestone: '16.9' },
          description: 'Scan Result Policies of the project',
          resolver: ::Resolvers::SecurityOrchestration::ScanResultPolicyResolver

        field :approval_policies,
          ::Types::SecurityOrchestration::ApprovalPolicyType.connection_type,
          calls_gitaly: true,
          null: true,
          description: 'Approval Policies of the project',
          resolver: ::Resolvers::SecurityOrchestration::ApprovalPolicyResolver

        field :security_policy_project,
          ::Types::ProjectType,
          null: true,
          method: :security_policy_management_project,
          description: 'Security policy project assigned to the namespace.'

        field :product_analytics_stored_events_limit,
          ::GraphQL::Types::Int,
          null: true,
          description: 'Number of product analytics events namespace is permitted to store per cycle.',
          alpha: { milestone: '16.9' },
          authorize: :modify_product_analytics_settings

        field :remote_development_cluster_agents,
          ::Types::Clusters::AgentType.connection_type,
          extras: [:lookahead],
          null: true,
          description: 'Cluster agents in the namespace with remote development capabilities',
          resolver: ::Resolvers::RemoteDevelopment::AgentsForNamespaceResolver

        def product_analytics_stored_events_limit
          object.root_ancestor.product_analytics_stored_events_limit
        end

        def additional_purchased_storage_size
          object.additional_purchased_storage_size.megabytes
        end

        def storage_size_limit
          object.root_ancestor.actual_plan.actual_limits.storage_size_limit.megabytes
        end
      end
    end
  end
end
