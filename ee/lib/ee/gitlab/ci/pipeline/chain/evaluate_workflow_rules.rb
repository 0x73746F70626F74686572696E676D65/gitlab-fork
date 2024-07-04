# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module EvaluateWorkflowRules
            extend ::Gitlab::Utils::Override

            private

            override :force_pipeline_creation_to_continue?
            def force_pipeline_creation_to_continue?
              command.pipeline_execution_policies.present?
            end
          end
        end
      end
    end
  end
end
