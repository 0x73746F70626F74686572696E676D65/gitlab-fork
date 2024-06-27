# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class CiConfigurationService < ::BaseService
      ACTION_CLASSES = {
        'secret_detection' => CiAction::Template,
        'container_scanning' => CiAction::Template,
        'sast' => CiAction::Template,
        'sast_iac' => CiAction::Template,
        'dependency_scanning' => CiAction::Template,
        'custom' => CiAction::Custom
      }.freeze

      def execute(action, ci_variables, context, index = 0)
        action_class = ACTION_CLASSES[action[:scan]] || CiAction::Unknown

        opts = {
          allow_restricted_variables_at_policy_level: allow_restricted_variables_at_policy_level?,
          scan_execution_policies_with_latest_templates: scan_execution_policies_with_latest_templates?
        }

        action_class.new(action, ci_variables, context, index, opts).config
      end

      private

      def allow_restricted_variables_at_policy_level?
        Feature.enabled?(:allow_restricted_variables_at_policy_level, project, type: :beta)
      end

      def scan_execution_policies_with_latest_templates?
        Feature.enabled?(:scan_execution_policies_with_latest_templates, project, type: :gitlab_com_derisk) ||
          Feature.enabled?(
            :scan_execution_policies_with_latest_templates_group,
            project.group,
            type: :gitlab_com_derisk
          )
      end
    end
  end
end
