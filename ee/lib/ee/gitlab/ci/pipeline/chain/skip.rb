# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module Skip
            extend ::Gitlab::Utils::Override

            private

            override :skipped?
            def skipped?
              return super if ::Feature.disabled?(:pipeline_execution_policy_type, project.group) ||
                command.execution_policy_pipelines.blank?

              # We don't allow pipeline to be skipped if it has to run execution policy pipelines
              false
            end
          end
        end
      end
    end
  end
end
