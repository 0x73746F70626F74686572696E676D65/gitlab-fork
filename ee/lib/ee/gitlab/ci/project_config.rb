# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module ProjectConfig
        extend ::Gitlab::Utils::Override

        private

        override :sources
        def sources
          # SecurityPolicyDefault should come last. It is only necessary if no other source is available.
          sources = [::Gitlab::Ci::ProjectConfig::Compliance].concat(super)
          # PipelineExecutionPolicyForced must come before AutoDevops because it handles
          # the empty CI config case.
          # We want to run Pipeline Execution Policies instead of AutoDevops (if they are present).
          insert_before_autodevops(sources, ::Gitlab::Ci::ProjectConfig::PipelineExecutionPolicyForced)
          sources.concat([::Gitlab::Ci::ProjectConfig::SecurityPolicyDefault])
        end

        def insert_before_autodevops(sources, new_source)
          auto_devops_source_index = sources.find_index do |source|
            source == ::Gitlab::Ci::ProjectConfig::AutoDevops
          end

          sources.insert(auto_devops_source_index, new_source)
        end
      end
    end
  end
end
