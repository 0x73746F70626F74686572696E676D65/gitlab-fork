# frozen_string_literal: true

module Gitlab
  module Security
    module Orchestration
      class ProjectPipelineExecutionPolicies
        POLICY_LIMIT_PER_PIPELINE = 5

        def initialize(project)
          @project = project
        end

        # Returns the execution policies that are applicable to the project after evaluating the policy scope
        # The maximum number of policies applied to the pipeline is given by POLICY_LIMIT_PER_PIPELINE.
        # Group policies higher in the hierarchy have precedence. Within level, precedence is defined by policy index.
        # Example:
        #   Group: [policy1, policy2]
        #   Sub-group: [policy3, policy4]
        #   Project: [policy5, policy6]
        #
        #   Result: [policy5, policy4, policy3, policy2, policy1]
        def configs
          applicable_execution_policies_by_hierarchy
            .first(POLICY_LIMIT_PER_PIPELINE)
            .reverse # reverse the order to apply the policy highest in the hierarchy as last
            .map do |policy|
              policy[:content].to_yaml
            end
        end

        private

        def applicable_execution_policies_by_hierarchy
          policy_scope_service = ::Security::SecurityOrchestrationPolicies::PolicyScopeService.new(project: @project)

          configs_ordered_by_hierarchy
            .flat_map(&:active_pipeline_execution_policies)
            .select { |policy| policy_scope_service.policy_applicable?(policy) }
        end

        # Returns an array of configs for the project, ordered by hierarchy.
        # The first element is the most top-level group for which the policy is applicable.
        # The last is a project's policy (if applicable).
        def configs_ordered_by_hierarchy
          configs = ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations.new(@project)
                                                                                  .all.index_by(&:namespace_id)
          [nil, *@project.group&.self_and_ancestor_ids].filter_map { |id| configs[id] }.reverse
        end
      end
    end
  end
end
