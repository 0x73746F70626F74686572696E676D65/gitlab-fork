# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module PipelineExecutionPolicies
        # This class is responsible for injecting two reserved stages used by execution policy pipelines,
        # `.pipeline-policy-pre` and `.pipeline-policy-post`, into the CI config's stages.
        #
        # @example
        #   config[:stages] = ['.pre', 'build', 'test', 'deploy', '.post']
        #   ReservedStagesInjector.inject_reserved_stages(config)
        #   config[:stages]
        #   # => ['.pipeline-policy-pre', '.pre', 'build', 'test', 'deploy', '.post', '.pipeline-policy-post']
        class ReservedStagesInjector
          PRE_STAGE = '.pipeline-policy-pre'
          POST_STAGE = '.pipeline-policy-post'
          STAGES = [PRE_STAGE, POST_STAGE].freeze

          # Injects the reserved stages into the CI config
          #
          # @param config [Hash] CI config hash
          # @return [Hash] CI config hash with injected reserved stages
          def self.inject_reserved_stages(config)
            return unless config

            config = config.to_h.deep_dup
            # If stages are not declared in config, we use the default stages to inject the reserved stages into.
            config[:stages] = ::Gitlab::Ci::Config::Entry::Stages.default if config[:stages].blank?

            config[:stages] = [PRE_STAGE, *(config[:stages].to_a - STAGES), POST_STAGE]
            config
          end
        end
      end
    end
  end
end
