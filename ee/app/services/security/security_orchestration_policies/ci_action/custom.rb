# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module CiAction
      class Custom < Base
        def config
          @ci_config = Gitlab::Ci::Config.new(yaml_config, inject_edge_stages: false, user: @context.user)

          job_names = parse_job_names

          @ci_config = @ci_config.to_hash

          assign_default_stage(job_names)

          @ci_config.delete(:stages)

          @ci_config
        rescue Gitlab::Ci::Config::ConfigError => e
          {
            generate_job_name_with_index('security_policy_ci') => {
              'script' => "echo \"Error parsing security policy CI configuration: #{e.message}\" && false",
              'allow_failure' => true
            }
          }
        end

        private

        def parse_job_names
          @ci_config.jobs.present? ? @ci_config.jobs.keys : []
        end

        def assign_default_stage(job_names)
          job_names.each do |name|
            unless @ci_config[name].key?(:stage)
              @ci_config[name][:stage] =
                ::Gitlab::Ci::Config::SecurityOrchestrationPolicies::Processor::DEFAULT_POLICY_TEST_STAGE
            end
          end
        end

        def yaml_config
          action[:ci_configuration] || { include: action[:ci_configuration_path] }.to_yaml
        end
      end
    end
  end
end
