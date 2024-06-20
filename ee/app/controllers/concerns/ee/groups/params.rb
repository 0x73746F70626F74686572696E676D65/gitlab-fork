# frozen_string_literal: true

module EE
  module Groups
    module Params
      extend ::Gitlab::Utils::Override
      include PreventForkingHelper
      include ServiceAccessTokenExpirationHelper
      include GitlabSubscriptions::SubscriptionHelper

      override :group_params_attributes
      def group_params_attributes
        super + group_params_ee
      end

      override :group_feature_attributes
      def group_feature_attributes
        return super unless current_group&.licensed_feature_available?(:group_wikis)

        super + [:wiki_access_level]
      end

      private

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- The .tap block
      # requires many necessary checks for each parameter.
      def group_params_ee
        [
          :membership_lock,
          :repository_size_limit,
          :new_user_signups_cap
        ].tap do |params_ee|
          params_ee << { insight_attributes: [:id, :project_id, :_destroy] } if current_group&.insights_available?

          if current_group&.feature_available?(:group_level_analytics_dashboard)
            params_ee << { analytics_dashboards_pointer_attributes: [:id, :target_project_id, :_destroy] }
          end

          if current_group&.feature_available?(:custom_file_templates_for_namespace)
            params_ee << :file_template_project_id
          end

          params_ee << :custom_project_templates_group_id if current_group&.group_project_template_available?
          params_ee << :ip_restriction_ranges if current_group&.licensed_feature_available?(:group_ip_restriction)
          params_ee << :allowed_email_domains_list if current_group&.feature_available?(:group_allowed_email_domains)
          params_ee << :max_pages_size if can?(current_user, :update_max_pages_size)

          if current_group&.personal_access_token_expiration_policy_available?
            params_ee << :max_personal_access_token_lifetime
          end

          params_ee << :prevent_forking_outside_group if can_change_prevent_forking?(current_user, current_group)

          if can_change_service_access_tokens_expiration?(current_user, current_group)
            params_ee << :service_access_tokens_expiration_enforced
          end

          params_ee << :enforce_ssh_certificates if current_group&.ssh_certificates_available?

          if can?(current_user, :modify_value_stream_dashboard_settings, current_group)
            params_ee << { value_stream_dashboard_aggregation_attributes: [:enabled] }
          end

          if experiment_settings_allowed?
            params_ee.push(:experiment_features_enabled, :early_access_program_participant)
          end

          params_ee.push(%i[duo_features_enabled lock_duo_features_enabled]) if licensed_ai_features_available?
          params_ee << :disable_personal_access_tokens
          params_ee << :enable_auto_assign_gitlab_duo_pro_seats if allow_update_enable_auto_assign_gitlab_duo_pro_seats?
        end + security_policies_toggle_params
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def security_policies_toggle_params
        security_policy_custom_ci_toggle_params
      end

      def security_policy_custom_ci_toggle_params
        return [] if ::Feature.disabled?(:compliance_pipeline_in_policies, current_group)

        [
          :toggle_security_policy_custom_ci,
          :lock_toggle_security_policy_custom_ci
        ]
      end

      def allow_update_enable_auto_assign_gitlab_duo_pro_seats?
        ::Feature.enabled?(:auto_assign_gitlab_duo_pro_seats, current_group) &&
          gitlab_com_subscription? && current_group&.root? &&
          can?(current_user, :admin_group, current_group) && current_group&.code_suggestions_purchased?
      end

      def experiment_settings_allowed?
        current_group&.experiment_settings_allowed?
      end

      def licensed_ai_features_available?
        current_group&.licensed_ai_features_available?
      end

      def current_group
        @group
      end
    end
  end
end
