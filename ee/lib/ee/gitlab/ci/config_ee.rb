# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      # This is named ConfigEE to avoid collisions with the
      # EE::Gitlab::Ci::Config namespace
      module ConfigEE
        extend ::Gitlab::Utils::Override

        override :build_config
        def build_config(config)
          super
            .then { |config| process_security_orchestration_policy_includes(config) }
        end

        def process_security_orchestration_policy_includes(config)
          ::Gitlab::Ci::Config::SecurityOrchestrationPolicies::Processor.new(config, context, source_ref_path,
            source).perform
        end
      end
    end
  end
end
