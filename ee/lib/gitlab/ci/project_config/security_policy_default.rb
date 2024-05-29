# frozen_string_literal: true

module Gitlab
  module Ci
    class ProjectConfig
      class SecurityPolicyDefault < Gitlab::Ci::ProjectConfig::Source
        def content
          return unless @triggered_for_branch
          return unless Enums::Ci::Pipeline.ci_and_security_orchestration_sources.key?(@pipeline_source)
          return unless @project.licensed_feature_available?(:security_orchestration_policies)
          return unless active_scan_execution_policies?

          # We merge the security scans with the pipeline configuration in ee/lib/ee/gitlab/ci/config_ee.rb.
          # An empty config with no content is enough to trigger the merge process when the Auto DevOps is disabled
          # and no .gitlab-ci.yml is present.
          YAML.dump(nil)
        end
        strong_memoize_attr :content

        def source
          :security_policies_default_source
        end

        private

        def active_scan_execution_policies?
          return false unless @ref

          service = ::Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: @project)

          ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations
            .new(@project).all
            .to_a
            .flat_map(&:active_scan_execution_policies_for_pipelines)
            .any? { |policy| policy_applicable?(policy) && applicable_for_branch?(service, policy) }
        end

        def policy_applicable?(policy)
          ::Security::SecurityOrchestrationPolicies::PolicyScopeService
            .new(project: @project)
            .policy_applicable?(policy)
        end

        def applicable_for_branch?(service, policy)
          applicable_branches = service.scan_execution_branches(policy[:rules])

          @ref.in?(applicable_branches)
        end
      end
    end
  end
end
