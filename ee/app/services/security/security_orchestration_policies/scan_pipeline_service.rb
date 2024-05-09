# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ScanPipelineService
      SCAN_VARIABLES = {
        secret_detection: {
          'SECRET_DETECTION_HISTORIC_SCAN' => 'false'
        }
      }.freeze

      SCAN_VARIABLES_WITH_RESTRICTED_VARIABLES = {
        secret_detection: {
          'SECRET_DETECTION_HISTORIC_SCAN' => 'false',
          'SECRET_DETECTION_EXCLUDED_PATHS' => ''
        },
        dependency_scanning: {
          'DS_EXCLUDED_PATHS' => 'spec, test, tests, tmp'
        },
        sast: {
          'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp'
        },
        sast_iac: {
          'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp'
        }
      }.freeze

      attr_reader :project, :base_variables, :context, :custom_ci_yaml_allowed

      def initialize(context, base_variables: {}, custom_ci_yaml_allowed: false)
        default_scan_variables = allow_restricted_variables? ? SCAN_VARIABLES_WITH_RESTRICTED_VARIABLES : SCAN_VARIABLES

        @project = context.project
        @context = context
        @base_variables = default_scan_variables.deep_merge(base_variables)
        @custom_ci_yaml_allowed = custom_ci_yaml_allowed
      end

      def execute(actions)
        actions = actions.select do |action|
          (valid_scan_type?(action[:scan]) && pipeline_scan_type?(action[:scan].to_s)) ||
            custom_scan?(action)
        end

        on_demand_scan_actions, other_actions = actions.partition do |action|
          on_demand_scan_type?(action[:scan].to_s)
        end

        pipeline_scan_configs = other_actions.map.with_index do |action, index|
          prepare_policy_configuration(action, index)
        end

        on_demand_configs = prepare_on_demand_policy_configuration(on_demand_scan_actions)

        pipeline_variables = collect_config_variables(other_actions, pipeline_scan_configs)
        on_demand_variables = collect_config_variables(on_demand_scan_actions, on_demand_configs)
        variables = pipeline_variables.merge(on_demand_variables)

        { pipeline_scan: pipeline_scan_configs.reduce({}, :merge),
          on_demand: on_demand_configs.reduce({}, :merge),
          variables: variables }
      end

      private

      def collect_config_variables(actions, configs)
        actions.zip(configs).each_with_object({}) do |(action, config), hash|
          variables = scan_variables_with_action_variables(action, fallback: action_variables(action))
          jobs = custom_scan?(action) ? Gitlab::Ci::Config.new(config.to_yaml).jobs : config

          jobs&.each_key do |key|
            hash[key] = variables
          end
        end
      end

      def pipeline_scan_type?(scan_type)
        scan_type.in?(Security::ScanExecutionPolicy::PIPELINE_SCAN_TYPES)
      end

      def on_demand_scan_type?(scan_type)
        scan_type.in?(Security::ScanExecutionPolicy::ON_DEMAND_SCANS)
      end

      def valid_scan_type?(scan_type)
        Security::ScanExecutionPolicy.valid_scan_type?(scan_type)
      end

      def custom_scan?(action)
        custom_ci_yaml_enabled? && action[:scan] == 'custom'
      end

      def prepare_on_demand_policy_configuration(actions)
        return {} if actions.blank?

        Security::SecurityOrchestrationPolicies::OnDemandScanPipelineConfigurationService
          .new(project)
          .execute(actions)
      end

      def prepare_policy_configuration(action, index)
        return unless valid_scan_type?(action[:scan]) || custom_scan?(action)

        variables = scan_variables_with_action_variables(action, fallback: scan_variables(action))

        ::Security::SecurityOrchestrationPolicies::CiConfigurationService
          .new(project)
          .execute(action, variables, context, index)
          .deep_symbolize_keys
      end

      def scan_variables(action)
        base_variables[action[:scan].to_sym].to_h
      end

      def action_variables(action)
        action[:variables].to_h.stringify_keys
      end

      def scan_variables_with_action_variables(action, fallback: {})
        return fallback unless allow_restricted_variables?

        scan_variables(action).merge(action_variables(action))
      end

      def custom_ci_yaml_enabled?
        return false if project.group.nil?

        custom_ci_yaml_allowed && compliance_pipeline_in_policies_enabled? && custom_ci_experiment_enabled?
      end

      def compliance_pipeline_in_policies_enabled?
        Feature.enabled?(:compliance_pipeline_in_policies, project)
      end

      def allow_restricted_variables?
        Feature.enabled?(:allow_restricted_variables_at_policy_level, project, type: :beta)
      end

      def custom_ci_experiment_enabled?
        return false if project.group.nil?

        project.group.namespace_settings.toggle_security_policy_custom_ci?
      end
    end
  end
end
