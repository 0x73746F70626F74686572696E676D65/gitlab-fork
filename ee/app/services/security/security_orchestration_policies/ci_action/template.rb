# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module CiAction
      class Template < Base
        SCAN_TEMPLATES = {
          'secret_detection' => 'Jobs/Secret-Detection',
          'container_scanning' => 'Jobs/Container-Scanning',
          'sast' => 'Jobs/SAST',
          'sast_iac' => 'Jobs/SAST-IaC',
          'dependency_scanning' => 'Jobs/Dependency-Scanning'
        }.freeze
        EXCLUDED_VARIABLES_PATTERNS = %w[_DISABLED _EXCLUDED_PATHS].freeze
        CONDITIONALLY_EXCLUDED_VARIABLES_PATTERNS = %w[_EXCLUDED_ANALYZERS].freeze
        LATEST_TEMPLATE_TYPE = 'latest'

        def config
          scan_type = @action[:scan]
          template = @action[:template]
          ci_configuration = scan_template(scan_type, template)
          variables = merge_variables(ci_configuration.delete(:variables), @ci_variables)

          ci_configuration.reject! { |job_name, _| hidden_job?(job_name) }
          ci_configuration.transform_keys! { |job_name| generate_job_name_with_index(job_name) }

          ci_configuration.each do |_, job_configuration|
            apply_variables!(job_configuration, variables)
            apply_tags!(job_configuration, @action[:tags])
            remove_extends!(job_configuration)
            remove_rule_to_disable_job!(job_configuration, ci_variables)
          end

          ci_configuration
        end

        private

        def scan_template(scan_type, template)
          template = ::TemplateFinder.build(:gitlab_ci_ymls, nil, name: scan_template_path(scan_type, template)).execute
          Gitlab::Ci::Config.new(template.content).to_hash
        end

        def scan_template_path(scan_type, template)
          scan_template_ci_path = SCAN_TEMPLATES[scan_type]
          return scan_template_ci_path unless @opts[:scan_execution_policies_with_latest_templates]
          return scan_template_ci_path if template != LATEST_TEMPLATE_TYPE

          "#{scan_template_ci_path}.#{LATEST_TEMPLATE_TYPE}"
        end

        def hidden_job?(job_name)
          job_name.start_with?('.')
        end

        def apply_variables!(job_configuration, variables)
          job_configuration[:variables] = merge_variables(job_configuration[:variables], variables)
        end

        def merge_variables(template_variables, variables)
          template_variables.to_h.stringify_keys.deep_merge(variables).compact
        end

        def apply_tags!(job_configuration, tags)
          return if tags.blank?

          job_configuration[:tags] = tags
        end

        def remove_extends!(job_configuration)
          job_configuration.delete(:extends)
        end

        def remove_rule_to_disable_job!(job_configuration, ci_variables)
          job_configuration[:rules]&.reject! do |rule|
            EXCLUDED_VARIABLES_PATTERNS.any? { |pattern| rule[:if]&.include?(pattern) } ||
              includes_restricted_variables_defined_at_policy_level?(rule, ci_variables)
          end
        end

        def includes_restricted_variables_defined_at_policy_level?(rule, ci_variables)
          CONDITIONALLY_EXCLUDED_VARIABLES_PATTERNS.any? do |pattern|
            rule[:if]&.include?(pattern) && (
              !@opts[:allow_restricted_variables_at_policy_level] ||
                ci_variables.none? { |variable, _| variable.to_s.include?(pattern) })
          end
        end
      end
    end
  end
end
