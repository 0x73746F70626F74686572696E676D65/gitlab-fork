# frozen_string_literal: true

module EE
  module GlobalPolicy
    extend ActiveSupport::Concern

    prepended do
      condition(:operations_dashboard_available) do
        License.feature_available?(:operations_dashboard)
      end

      condition(:pages_size_limit_available) do
        License.feature_available?(:pages_size_limit)
      end

      condition(:adjourned_project_deletion_available) do
        License.feature_available?(:adjourned_deletion_for_projects_and_groups)
      end

      condition(:export_user_permissions_available) do
        ::License.feature_available?(:export_user_permissions)
      end

      condition(:top_level_group_creation_enabled) do
        if ::Gitlab.com?
          ::Feature.enabled?(:top_level_group_creation_enabled, type: :ops)
        else
          true
        end
      end

      condition(:clickhouse_main_database_available) do
        ::Gitlab::ClickHouse.configured?
      end

      condition(:instance_devops_adoption_available) do
        ::License.feature_available?(:instance_level_devops_adoption)
      end

      condition(:runner_performance_insights_available) do
        ::License.feature_available?(:runner_performance_insights)
      end

      condition(:runner_upgrade_management_available) do
        License.feature_available?(:runner_upgrade_management)
      end

      condition(:service_accounts_available) do
        ::License.feature_available?(:service_accounts)
      end

      condition(:instance_external_audit_events_enabled) do
        ::License.feature_available?(:external_audit_events)
      end

      condition(:code_suggestions_licensed) do
        next true if ::Gitlab.org_or_com?

        ::License.feature_available?(:code_suggestions)
      end

      condition(:code_suggestions_enabled_for_user) do
        next false unless @user
        next true if CloudConnector::AvailableServices.find_by_name(:code_suggestions).allowed_for?(@user)

        next false unless ::Ai::FeatureSetting.code_suggestions_self_hosted?

        self_hosted_models = CloudConnector::AvailableServices.find_by_name(:self_hosted_models)
        self_hosted_models.free_access? || self_hosted_models.allowed_for?(@user)
      end

      condition(:duo_chat_enabled) do
        next true if ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
        next false unless ::License.feature_available?(:ai_chat)

        if duo_chat_free_access_was_cut_off?
          duo_chat.allowed_for?(@user)
        else # Before service start date
          ::Gitlab::CurrentSettings.duo_features_enabled?
        end
      end

      condition(:user_allowed_to_use_chat) do
        next false unless @user
        next true unless ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)

        if duo_chat_free_access_was_cut_off?
          duo_chat.allowed_for?(@user)
        else
          @user.any_group_with_ai_chat_available?
        end
      end

      condition(:user_belongs_to_paid_namespace) do
        next false unless @user

        @user.belongs_to_paid_namespace?
      end

      condition(:custom_roles_allowed) do
        ::License.feature_available?(:custom_roles)
      end

      condition(:user_allowed_to_manage_ai_settings) do
        next false unless ::Feature.enabled?(:self_managed_code_suggestions) # Can be removed post-rollout
        next false if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        ::License.current&.paid? # Replace with license :ai_self_hosted_model for GA
      end

      condition(:x_ray_available) do
        next true if ::Gitlab::Saas.feature_available?(:code_suggestions_x_ray)

        ::License.feature_available?(:code_suggestions)
      end

      rule { x_ray_available }.enable :access_x_ray_on_instance

      rule { ~anonymous & operations_dashboard_available }.enable :read_operations_dashboard

      condition(:remote_development_feature_licensed) do
        License.feature_available?(:remote_development)
      end

      rule { ~anonymous & remote_development_feature_licensed }.policy do
        enable :access_workspaces_feature
      end

      rule { admin & instance_devops_adoption_available }.policy do
        enable :manage_devops_adoption_namespaces
        enable :view_instance_devops_adoption
      end

      rule { admin }.policy do
        enable :read_licenses
        enable :destroy_licenses
        enable :read_all_geo
        enable :read_all_workspaces
        enable :manage_subscription
        enable :read_jobs_statistics
        enable :read_runner_usage
      end

      rule { admin & user_allowed_to_manage_ai_settings }.policy do
        enable :manage_ai_settings
      end

      rule { admin & custom_roles_allowed }.policy do
        enable :admin_member_role
      end

      rule { ~anonymous & custom_roles_allowed }.policy do
        enable :read_member_role
      end

      rule { admin & pages_size_limit_available }.enable :update_max_pages_size

      rule { ~runner_performance_insights_available }.policy do
        prevent :read_jobs_statistics
        prevent :read_runner_usage
      end

      rule { ~clickhouse_main_database_available }.prevent :read_runner_usage

      rule { admin & service_accounts_available }.enable :admin_service_accounts

      rule { ~anonymous }.policy do
        enable :view_productivity_analytics
      end

      rule { ~(admin | allow_to_manage_default_branch_protection) }.policy do
        prevent :create_group_with_default_branch_protection
      end

      rule { adjourned_project_deletion_available }.policy do
        enable :list_removable_projects
      end

      rule { export_user_permissions_available & admin }.enable :export_user_permissions

      rule { can?(:create_group) }.enable :create_group_via_api
      rule { ~top_level_group_creation_enabled }.prevent :create_group_via_api

      rule { admin & instance_external_audit_events_enabled }.policy do
        enable :admin_instance_external_audit_events
      end

      rule { code_suggestions_licensed & code_suggestions_enabled_for_user }.enable :access_code_suggestions

      rule { user_allowed_to_use_chat & duo_chat_enabled }.enable :access_duo_chat

      rule { runner_upgrade_management_available | user_belongs_to_paid_namespace }.enable :read_runner_upgrade_status

      rule { security_policy_bot }.policy do
        enable :access_git
      end

      condition(:generate_commit_message_licensed) do
        next false unless ::Feature.enabled?(:generate_commit_message_flag, @user)

        ::License.feature_available?(:generate_commit_message)
      end

      condition(:user_allowed_to_use_generate_commit_message) do
        if generate_commit_message_data.free_access?
          user.any_group_with_ai_available?
        else
          generate_commit_message_data.allowed_for?(@user)
        end
      end

      rule { generate_commit_message_licensed & user_allowed_to_use_generate_commit_message }.policy do
        enable :access_generate_commit_message
      end
    end

    def generate_commit_message_data
      CloudConnector::AvailableServices.find_by_name(:generate_commit_message)
    end

    def duo_chat_free_access_was_cut_off?
      if ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)
        duo_chat_free_access_was_cut_off_for_gitlab_com?
      else
        duo_chat_free_access_was_cut_off_for_sm?
      end
    end

    def duo_chat_free_access_was_cut_off_for_gitlab_com?
      # TODO: update with the hardcoded cut-off date check, https://gitlab.com/gitlab-org/gitlab/-/issues/440386
      user.belongs_to_group_requires_licensed_seat_for_chat?
    end

    def duo_chat_free_access_was_cut_off_for_sm?
      ::Feature.enabled?(:duo_chat_requires_licensed_seat_sm) ||
        !duo_chat.free_access?
    end

    def duo_chat
      CloudConnector::AvailableServices.find_by_name(:duo_chat)
    end
  end
end
