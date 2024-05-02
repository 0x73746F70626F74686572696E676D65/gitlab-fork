# frozen_string_literal: true

module EE
  module Gitlab
    module Saas
      extend ActiveSupport::Concern

      MissingFeatureError = Class.new(StandardError)

      FEATURES =
        %i[
          ai_vertex_embeddings
          experimentation
          marketing_google_tag_manager
          namespaces_storage_limit
          onboarding
          purchases_additional_minutes
          search_indexing_status
          subscriptions_trials
          gitlab_com_subscriptions
          duo_chat_categorize_question
          google_cloud_support
          duo_chat_on_saas
          exact_code_search
          overage_members_modal
          advanced_search
          code_suggestions_x_ray
          identity_verification
          gitlab_duo_saas_only
          beta_rollout_pre_receive_secret_detection
        ].freeze

      CONFIG_FILE_ROOT = 'ee/config/saas_features'

      class_methods do
        def feature_available?(feature)
          raise MissingFeatureError, 'Feature does not exist' unless FEATURES.include?(feature)

          enabled?
        end

        def enabled?
          # Use existing checks initially. We can allow it only in this place and remove it anywhere else.
          # eventually we can change its implementation like using an ENV variable for each instance
          # or any other method that people can't mess with.
          ::Gitlab.com? # rubocop:disable Gitlab/AvoidGitlabInstanceChecks  -- See above comment
        end

        def feature_file_path(feature)
          Rails.root.join(CONFIG_FILE_ROOT, "#{feature}.yml")
        end
      end
    end
  end
end
