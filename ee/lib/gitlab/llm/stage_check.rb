# frozen_string_literal: true

module Gitlab
  module Llm
    class StageCheck
      EXPERIMENTAL_FEATURES = [
        :ai_analyze_ci_job_failure,
        :summarize_comments,
        :summarize_my_mr_code_review,
        :explain_code,
        :generate_description,
        :explain_vulnerability,
        :resolve_vulnerability,
        :generate_commit_message,
        :fill_in_merge_request_template,
        :summarize_new_merge_request,
        :summarize_submitted_review,
        :ai_review_merge_request
      ].freeze
      BETA_FEATURES = [].freeze
      GA_FEATURES = [:chat].freeze

      class << self
        def available?(container, feature)
          root_ancestor = container.root_ancestor

          return false if personal_namespace?(root_ancestor)
          return false unless root_ancestor.licensed_feature_available?(license_feature_name(feature))

          available_on_experimental_stage?(root_ancestor, feature) ||
            available_on_beta_stage?(root_ancestor, feature) ||
            available_on_ga_stage?(feature)
        end

        private

        def personal_namespace?(root_ancestor)
          root_ancestor.user_namespace?
        end

        def available_on_experimental_stage?(root_ancestor, feature)
          return false unless instance_allows_experiment_and_beta_features
          return false unless gitlab_com_namespace_enables_experiment_and_beta_features(root_ancestor)
          return false unless EXPERIMENTAL_FEATURES.include?(feature)

          true
        end

        # There is no beta setting yet.
        # https://gitlab.com/gitlab-org/gitlab/-/issues/409929
        def available_on_beta_stage?(root_ancestor, feature)
          return false unless instance_allows_experiment_and_beta_features
          return false unless gitlab_com_namespace_enables_experiment_and_beta_features(root_ancestor)
          return false unless BETA_FEATURES.include?(feature)

          true
        end

        def available_on_ga_stage?(feature)
          return true if GA_FEATURES.include?(feature)

          false
        end

        def license_feature_name(feature)
          feature == :chat ? :ai_chat : :ai_features
        end

        def instance_allows_experiment_and_beta_features
          if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
            true
          else
            # experiment features are only available on .com until we implement
            # https://gitlab.com/groups/gitlab-org/-/epics/13400
            false
          end
        end

        def gitlab_com_namespace_enables_experiment_and_beta_features(namespace)
          # namespace-level settings check is only relevant for .com
          return true unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)

          if namespace.experiment_features_enabled
            true
          else
            false
          end
        end
      end
    end
  end
end

# Added for JiHu
::Gitlab::Llm::StageCheck.prepend_mod
