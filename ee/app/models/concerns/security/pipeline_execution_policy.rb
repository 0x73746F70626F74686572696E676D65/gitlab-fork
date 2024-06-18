# frozen_string_literal: true

module Security
  module PipelineExecutionPolicy
    # This is the maximum number of PEPs in a policy config file
    POLICY_LIMIT = 5

    def active_pipeline_execution_policies
      pipeline_execution_policy.select { |config| config[:enabled] }.first(POLICY_LIMIT)
    end

    def pipeline_execution_policy
      policy_by_type(:pipeline_execution_policy)
    end
  end
end
