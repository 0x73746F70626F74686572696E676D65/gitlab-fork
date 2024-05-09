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

        opts = { allow_restricted_variables_at_policy_level: allow_restricted_variables_at_policy_level? }

        action_class.new(action, ci_variables, context, index, opts).config
      end

      private

      def allow_restricted_variables_at_policy_level?
        Feature.enabled?(:allow_restricted_variables_at_policy_level, project, type: :beta)
      end
    end
  end
end
