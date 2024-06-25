# frozen_string_literal: true

# This class encapsulates functionality related to Pipeline Execution Policies and is used during pipeline creation.
module Gitlab
  module Ci
    module Pipeline
      module PipelineExecutionPolicies
        class PipelineContext
          def initialize(project:, command: nil)
            @project = project
            @command = command
          end

          def execution_policy_mode?
            command&.execution_policy_mode? || false
          end

          def has_execution_policy_pipelines?
            command&.execution_policy_pipelines.present? || false
          end

          # We inject reserved policy stages only when;
          # - execution_policy_mode: This is a temporary pipeline creation mode.
          #   We need to inject these stages for the validation because the policy may use them.
          # - has_execution_policy_pipelines?: This is the actual pipeline creation mode.
          #   It means that the result pipeline will have PEPs.
          #   We need to inject these stages because some of the policies may use them.
          def inject_policy_reserved_stages?
            return false if ::Feature.disabled?(:pipeline_execution_policy_type, project&.group)

            execution_policy_mode? || has_execution_policy_pipelines?
          end

          def valid_stage?(stage)
            return true if ::Feature.disabled?(:pipeline_execution_policy_type, project&.group) ||
              execution_policy_mode?

            ReservedStagesInjector::STAGES.exclude?(stage)
          end

          private

          attr_reader :project, :command
        end
      end
    end
  end
end
