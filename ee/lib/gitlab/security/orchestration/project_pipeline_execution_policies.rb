# frozen_string_literal: true

module Gitlab
  module Security
    module Orchestration
      class ProjectPipelineExecutionPolicies
        def initialize(project)
          @project = project
        end

        def yaml_contents
          configs = ::Gitlab::Security::Orchestration::ProjectPolicyConfigurations.new(@project).all
          configs.flat_map(&:active_pipeline_execution_policies).filter_map do |policy|
            policy[:content]&.to_yaml
          end
        end
      end
    end
  end
end
