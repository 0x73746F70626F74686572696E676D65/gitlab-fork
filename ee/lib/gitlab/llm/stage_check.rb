# frozen_string_literal: true

module Gitlab
  module Llm
    class StageCheck
      EXPERIMENTAL_FEATURES = [
        :ai_analyze_ci_job_failure,
        :summarize_notes,
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
      GA_FEATURES = [].freeze

      class << self
        def available?(container, feature)
          available_on_experimental_stage?(container, feature) ||
            available_on_beta_stage?(container, feature) ||
            available_on_ga_stage?(container, feature)
        end

        private

        def available_on_experimental_stage?(container, feature)
          return false unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)

          return false unless EXPERIMENTAL_FEATURES.include?(feature)

          root_ancestor = container&.root_ancestor
          return false unless root_ancestor&.experiment_features_enabled

          root_ancestor.licensed_feature_available?(:ai_features)
        end

        # There is no beta setting yet.
        # https://gitlab.com/gitlab-org/gitlab/-/issues/409929
        def available_on_beta_stage?(container, feature)
          return false unless beta_features.include?(feature)

          root_ancestor = container&.root_ancestor
          return false unless root_ancestor&.experiment_features_enabled

          root_ancestor.licensed_feature_available?(license_feature_name(feature))
        end

        def available_on_ga_stage?(container, feature)
          return false unless ga_features.include?(feature)

          root_ancestor = container&.root_ancestor
          root_ancestor.licensed_feature_available?(license_feature_name(feature))
        end

        def license_feature_name(feature)
          feature == :chat ? :ai_chat : :ai_features
        end

        def beta_features
          BETA_FEATURES.dup.tap { |features| features << :chat if Feature.disabled?(:duo_chat_ga) }
        end

        def ga_features
          GA_FEATURES.dup.tap { |features| features << :chat if Feature.enabled?(:duo_chat_ga) }
        end
      end
    end
  end
end

# Added for JiHu
::Gitlab::Llm::StageCheck.prepend_mod
