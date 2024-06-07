# frozen_string_literal: true

module EE
  module ProjectPolicy
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include ReadonlyAbilities

      desc "User is a security policy bot on the project"
      condition(:security_policy_bot) { user&.security_policy_bot? && team_member? }

      with_scope :subject
      condition(:repository_mirrors_enabled) { @subject.feature_available?(:repository_mirrors) }

      with_scope :subject
      condition(:iterations_available) { @subject.group&.licensed_feature_available?(:iterations) }

      with_scope :subject
      condition(:requirements_available) { @subject.feature_available?(:requirements) & access_allowed_to?(:requirements) }

      with_scope :subject
      condition(:quality_management_available) { @subject.feature_available?(:quality_management) }

      condition(:compliance_framework_available) { @subject.feature_available?(:compliance_framework, @user) }

      with_scope :global
      condition(:is_development) { Rails.env.development? }

      with_scope :global
      condition(:ai_available) do
        ::Feature.enabled?(:ai_global_switch, type: :ops)
      end

      with_scope :subject
      condition(:generate_cube_query_enabled) do
        ::Feature.enabled?(:generate_cube_query, @subject) &&
          @subject.licensed_feature_available?(:ai_generate_cube_query)
      end

      with_scope :global
      condition(:locked_approvers_rules) do
        !@user.can_admin_all_resources? &&
          License.feature_available?(:admin_merge_request_approvers_rules) &&
          ::Gitlab::CurrentSettings.disable_overriding_approvers_per_merge_request
      end

      condition(:group_merge_request_approval_settings_enabled) do
        @subject.feature_available?(:merge_request_approvers)
      end

      with_scope :global
      condition(:locked_merge_request_author_setting) do
        License.feature_available?(:admin_merge_request_approvers_rules) &&
          ::Gitlab::CurrentSettings.prevent_merge_requests_author_approval
      end

      with_scope :global
      condition(:locked_merge_request_committer_setting) do
        License.feature_available?(:admin_merge_request_approvers_rules) &&
          ::Gitlab::CurrentSettings.prevent_merge_requests_committers_approval
      end

      with_scope :subject
      condition(:dora4_analytics_available) do
        @subject.feature_available?(:dora4_analytics)
      end

      condition(:project_merge_request_analytics_available) do
        @subject.feature_available?(:project_merge_request_analytics)
      end

      condition(:push_rules_available, scope: :subject) do
        @subject.feature_available?(:push_rules)
      end

      condition(:commit_committer_check_available, scope: :subject) do
        @subject.feature_available?(:commit_committer_check)
      end

      condition(:commit_committer_name_check_available, scope: :subject) do
        @subject.feature_available?(:commit_committer_name_check)
      end

      condition(:reject_unsigned_commits_available, scope: :subject) do
        @subject.feature_available?(:reject_unsigned_commits)
      end

      condition(:reject_non_dco_commits_available, scope: :subject) do
        @subject.feature_available?(:reject_non_dco_commits)
      end

      condition(:security_orchestration_policies_enabled, scope: :subject) do
        @subject.feature_available?(:security_orchestration_policies)
      end

      condition(:security_dashboard_enabled, scope: :subject) do
        @subject.feature_available?(:security_dashboard)
      end

      condition(:coverage_fuzzing_enabled, scope: :subject) do
        @subject.feature_available?(:coverage_fuzzing)
      end

      condition(:on_demand_scans_enabled, scope: :subject) do
        @subject.on_demand_dast_available?
      end

      condition(:license_scanning_enabled, scope: :subject) do
        @subject.feature_available?(:license_scanning)
      end

      condition(:dependency_scanning_enabled, scope: :subject) do
        @subject.feature_available?(:dependency_scanning)
      end

      condition(:code_review_analytics_enabled) do
        @subject.feature_available?(:code_review_analytics, @user)
      end

      condition(:issue_analytics_enabled) do
        @subject.feature_available?(:issues_analytics, @user)
      end

      condition(:combined_project_analytics_dashboards_enabled) do
        @subject.feature_available?(:combined_project_analytics_dashboards, @user)
      end

      condition(:google_cloud_support_available, scope: :global) do
        ::Gitlab::Saas.feature_available?(:google_cloud_support)
      end

      condition(:status_page_available) do
        @subject.feature_available?(:status_page, @user)
      end

      condition(:read_only, scope: :subject) do
        @subject.root_namespace.read_only?
      end

      condition(:feature_flags_related_issues_disabled, scope: :subject) do
        !@subject.feature_available?(:feature_flags_related_issues)
      end

      condition(:oncall_schedules_available, scope: :subject) do
        ::Gitlab::IncidentManagement.oncall_schedules_available?(@subject)
      end

      condition(:escalation_policies_available, scope: :subject) do
        ::Gitlab::IncidentManagement.escalation_policies_available?(@subject)
      end

      condition(:hidden, scope: :subject) do
        @subject.hidden?
      end

      condition(:membership_locked_via_parent_group, scope: :subject) do
        @subject.group && (
          @subject.group.membership_lock? ||
          ::Gitlab::CurrentSettings.lock_memberships_to_ldap? ||
          ::Gitlab::CurrentSettings.lock_memberships_to_saml)
      end

      condition(:security_policy_project_available, scope: :subject) do
        @subject.security_orchestration_policy_configuration.present?
      end

      condition(:can_commit_to_security_policy_project) do
        security_orchestration_policy_configuration = @subject.security_orchestration_policy_configuration

        next unless security_orchestration_policy_configuration

        Ability.allowed?(@user, :developer_access, security_orchestration_policy_configuration.security_policy_management_project)
      end

      condition(:okrs_enabled, scope: :subject) do
        @subject.okrs_mvc_feature_flag_enabled? && @subject.feature_available?(:okrs)
      end

      condition(:licensed_cycle_analytics_available, scope: :subject) do
        @subject.feature_available?(:cycle_analytics_for_projects)
      end

      condition(:agent_registry_enabled, scope: :subject) do
        ::Feature.enabled?(:agent_registry, @subject) && @subject.licensed_feature_available?(:ai_agents)
      end

      condition(:user_banned_from_namespace) do
        next unless @user.is_a?(User)
        next if @user.can_admin_all_resources?
        # Loading the namespace_bans association is intentional because it is going to
        # be used in the banned_from_namespace? check below
        next if @user.namespace_bans.to_a.empty?

        groups = @subject.invited_groups + [@subject.group]
        groups.compact!
        next if groups.empty?

        groups.any? do |group|
          next unless group.root_ancestor.unique_project_download_limit_enabled?

          @user.banned_from_namespace?(group.root_ancestor)
        end
      end

      rule { membership_locked_via_parent_group }.policy do
        prevent :import_project_members_from_another_project
      end

      condition(:custom_roles_allowed) do
        @subject.custom_roles_enabled?
      end

      MemberRole.all_customizable_project_permissions.each do |ability|
        desc "Custom role on project that enables #{ability.to_s.tr('_', ' ')}"
        condition("custom_role_enables_#{ability}".to_sym) do
          ::Authz::CustomAbility.allowed?(@user, ability, @subject)
        end
      end

      with_scope :subject
      condition(:suggested_reviewers_available) do
        @subject.can_suggest_reviewers?
      end

      with_scope :subject
      condition(:fill_in_merge_request_template_enabled) do
        ::Feature.enabled?(:fill_in_mr_template, subject) &&
          ::Gitlab::Llm::FeatureAuthorizer.new(
            container: subject,
            feature_name: :fill_in_merge_request_template
          ).allowed?
      end

      with_scope :subject
      condition(:summarize_new_merge_request_enabled) do
        ::Feature.enabled?(:add_ai_summary_for_new_mr, subject) &&
          ::Gitlab::Llm::FeatureAuthorizer.new(
            container: subject,
            feature_name: :summarize_new_merge_request
          ).allowed?
      end

      with_scope :subject
      condition(:generate_description_enabled) do
        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject,
          feature_name: :generate_description
        ).allowed?
      end

      with_scope :subject
      condition(:target_branch_rules_available) { subject.licensed_feature_available?(:target_branch_rules) }

      condition(:pages_multiple_versions_available) do
        ::Feature.enabled?(:pages_multiple_versions_setting, @subject) &&
          @subject.licensed_feature_available?(:pages_multiple_versions)
      end

      condition(:merge_requests_is_a_private_feature) do
        project.project_feature&.private?(:merge_requests)
      end

      condition(:tracing_enabled) do
        # Can be enabled for all projects in root namespace. Maintains backward
        # compatibility by falling back to checking against project
        (::Feature.enabled?(:observability_tracing,
          @subject.root_namespace) || ::Feature.enabled?(:observability_tracing, @subject)) &&
          @subject.licensed_feature_available?(:tracing)
      end

      condition(:observability_metrics_enabled) do
        ::Feature.enabled?(:observability_metrics, @subject.root_namespace) &&
          @subject.licensed_feature_available?(:metrics_observability)
      end

      condition(:observability_logs_enabled) do
        ::Feature.enabled?(:observability_logs, @subject.root_namespace, type: :wip) &&
          @subject.licensed_feature_available?(:logs_observability)
      end

      # We are overriding the already defined condition in CE version
      # to allow Guest users with member roles to access the merge requests.
      condition(:merge_requests_disabled) do
        !(access_allowed_to?(:merge_requests) ||
          (merge_requests_is_a_private_feature? && custom_role_enables_admin_merge_request?))
      end

      rule { custom_role_enables_admin_cicd_variables }.policy do
        enable :admin_cicd_variables
      end

      rule { custom_role_enables_admin_push_rules }.policy do
        enable :admin_push_rules
      end

      rule { custom_role_enables_admin_integrations }.policy do
        enable :admin_integrations
      end

      rule { custom_role_enables_admin_runners }.enable(*create_read_update_admin_destroy(:runner))

      condition(:ci_cancellation_maintainers_only, scope: :subject) do
        project.ci_cancellation_restriction.maintainers_only_allowed?
      end

      condition(:ci_cancellation_no_one, scope: :subject) do
        project.ci_cancellation_restriction.no_one_allowed?
      end

      condition(:chat_allowed_for_parent_group, scope: :subject) do
        next true unless ::Gitlab::Saas.feature_available?(:duo_chat_on_saas)

        ::Gitlab::Llm::StageCheck.available?(@subject.parent, :chat)
      end

      condition(:chat_available_for_user, scope: :user) do
        Ability.allowed?(@user, :access_duo_chat)
      end

      condition(:duo_features_enabled, scope: :subject) { @subject.duo_features_enabled }

      rule { visual_review_bot }.policy do
        prevent_all
      end

      rule { license_block }.policy do
        prevent :create_issue
        prevent :create_merge_request_in
        prevent :create_merge_request_from
        prevent :push_code
      end

      rule { analytics_disabled }.policy do
        prevent(:read_project_merge_request_analytics)
        prevent(:read_code_review_analytics)
        prevent(:read_issue_analytics)
      end

      rule { feature_flags_related_issues_disabled | repository_disabled }.policy do
        prevent :admin_feature_flags_issue_links
      end

      rule { can?(:guest_access) & iterations_available }.enable :read_iteration

      rule { can?(:reporter_access) }.policy do
        enable :admin_issue_board
      end

      rule { monitor_disabled }.policy do
        prevent :read_incident_management_oncall_schedule
        prevent :admin_incident_management_oncall_schedule
        prevent :read_incident_management_escalation_policy
        prevent :admin_incident_management_escalation_policy
      end

      rule { oncall_schedules_available & can?(:reporter_access) }.enable :read_incident_management_oncall_schedule
      rule { escalation_policies_available & can?(:reporter_access) }.enable :read_incident_management_escalation_policy

      rule { can?(:developer_access) }.policy do
        enable :admin_issue_board
        enable :admin_feature_flags_issue_links
        enable :read_project_audit_events
        enable :read_product_analytics
        enable :create_workspace
        enable :enable_continuous_vulnerability_scans
      end

      rule { can?(:reporter_access) & iterations_available }.policy do
        enable :create_iteration
        enable :admin_iteration
      end

      rule { custom_roles_allowed & can?(:admin_project_member) }.policy do
        enable :read_member_role
      end

      rule { can?(:read_project) & iterations_available }.enable :read_iteration

      rule { security_orchestration_policies_enabled & can?(:developer_access) }.policy do
        enable :read_security_orchestration_policies
      end

      rule { security_orchestration_policies_enabled & can?(:owner_access) }.policy do
        enable :update_security_orchestration_policy_project
      end

      rule { security_orchestration_policies_enabled & can?(:guest_access) }.policy do
        enable :read_security_orchestration_policy_project
      end

      rule { security_orchestration_policies_enabled & auditor }.policy do
        enable :read_security_orchestration_policies
      end

      rule { security_orchestration_policies_enabled & can?(:owner_access) & ~security_policy_project_available }.policy do
        enable :modify_security_policy
      end

      rule { security_orchestration_policies_enabled & security_policy_project_available & can_commit_to_security_policy_project }.policy do
        enable :modify_security_policy
      end

      rule { security_orchestration_policies_enabled & custom_role_enables_manage_security_policy_link }.policy do
        enable :read_security_orchestration_policies
        enable :read_security_orchestration_policy_project
        enable :update_security_orchestration_policy_project
        enable :access_security_and_compliance
      end

      rule { security_dashboard_enabled & can?(:developer_access) }.policy do
        enable :read_security_resource
      end

      rule { coverage_fuzzing_enabled & can?(:developer_access) }.policy do
        enable :read_coverage_fuzzing
        enable :create_coverage_fuzzing_corpus
      end

      rule { on_demand_scans_enabled & can?(:developer_access) }.policy do
        enable :read_on_demand_dast_scan
        enable :create_on_demand_dast_scan
        enable :edit_on_demand_dast_scan
      end

      rule { on_demand_scans_enabled & security_policy_bot }.policy do
        enable :read_on_demand_dast_scan
        enable :create_on_demand_dast_scan
      end

      # If licensed but not reporter+, prevent access
      rule { can?(:read_merge_request) & can?(:read_issue) & licensed_cycle_analytics_available }.policy do
        enable :read_cycle_analytics
      end

      # If licensed and reporter+, allow access
      rule { ((reporter | admin)) & licensed_cycle_analytics_available }.policy do
        enable :admin_value_stream
      end

      rule { can?(:read_merge_request) & can?(:read_pipeline) }.enable :read_merge_train

      rule { can?(:read_security_resource) }.policy do
        enable :read_project_security_dashboard
        enable :create_vulnerability_export
        enable :admin_vulnerability_issue_link
        enable :admin_vulnerability_merge_request_link
        enable :admin_vulnerability_external_issue_link
      end

      rule { can?(:read_security_resource) }.policy do
        enable :read_vulnerability
      end

      rule { can?(:read_security_resource) & can?(:maintainer_access) }.policy do
        enable :admin_vulnerability
      end

      rule { can?(:admin_vulnerability) }.policy do
        enable :read_vulnerability
        enable :create_vulnerability_feedback
        enable :destroy_vulnerability_feedback
        enable :update_vulnerability_feedback
      end

      rule { can?(:read_vulnerability) }.policy do
        enable :read_vulnerability_feedback
        enable :read_vulnerability_scanner
      end

      rule { security_and_compliance_disabled }.policy do
        prevent :admin_vulnerability
        prevent :read_vulnerability
      end

      rule { security_bot }.policy do
        enable :push_code
        enable :create_merge_request_from
        enable :create_vulnerability_feedback
        enable :admin_merge_request
      end

      rule { issues_disabled }.policy do
        prevent :read_issue_analytics
      end

      rule { merge_requests_disabled }.policy do
        prevent :read_project_merge_request_analytics
      end

      rule { issues_disabled & merge_requests_disabled }.policy do
        prevent(*create_read_update_admin_destroy(:iteration))
      end

      rule { dependency_scanning_enabled & can?(:download_code) }.enable :read_dependency

      rule { license_scanning_enabled & can?(:download_code) }.enable :read_licenses

      rule { can?(:read_licenses) }.enable :read_software_license_policy

      rule { repository_mirrors_enabled & ((mirror_available & can?(:admin_project)) | admin) }.enable :admin_mirror

      rule { can?(:maintainer_access) }.policy do
        enable :push_code_to_protected_branches
        enable :admin_path_locks
        enable :read_approvers
        enable :update_approvers
        enable :modify_approvers_rules
        enable :modify_merge_request_author_setting
        enable :modify_merge_request_committer_setting
        enable :modify_product_analytics_settings
        enable :admin_push_rules
        enable :manage_deploy_tokens
        enable :read_runner_usage
      end

      rule { ~runner_performance_insights_available }.prevent :read_runner_usage

      rule { ~clickhouse_main_database_available }.prevent :read_runner_usage

      rule { license_scanning_enabled & can?(:maintainer_access) }.enable :admin_software_license_policy

      rule { oncall_schedules_available & can?(:maintainer_access) }.enable :admin_incident_management_oncall_schedule
      rule { escalation_policies_available & can?(:maintainer_access) }.enable :admin_incident_management_escalation_policy

      rule { auditor }.policy do
        enable :public_user_access
        prevent :request_access

        enable :read_build
        enable :read_environment
        enable :read_deployment
        enable :read_pages
        enable :read_project_audit_events
        enable :read_cluster
        enable :read_terraform_state
        enable :read_project_merge_request_analytics
        enable :read_approvers
        enable :read_on_demand_dast_scan

        enable :read_project_runners
      end

      rule { auditor & ~guest & private_project }.policy do
        prevent :fork_project
        prevent :create_merge_request_in
      end

      rule { auditor }.policy do
        enable :access_security_and_compliance
      end

      rule { auditor & security_dashboard_enabled }.policy do
        enable :read_security_resource
      end

      rule { auditor & oncall_schedules_available }.policy do
        enable :read_incident_management_oncall_schedule
      end

      rule { auditor & escalation_policies_available }.policy do
        enable :read_incident_management_escalation_policy
      end

      rule { auditor & ~monitor_disabled }.policy do
        enable :read_alert_management_alert
      end

      rule { auditor & ~developer }.policy do
        prevent :admin_vulnerability_issue_link
        prevent :admin_vulnerability_external_issue_link
        prevent :admin_vulnerability_merge_request_link
        prevent :admin_vulnerability
      end

      rule { auditor & ~guest }.policy do
        prevent :create_project
        prevent :create_issue
        prevent :create_note
        prevent :upload_file
        prevent :admin_issue_link
      end

      rule { ~can?(:push_code) }.prevent :push_code_to_protected_branches

      rule { can?(:admin_push_rules) }.policy do
        enable :change_push_rules
        enable :read_commit_committer_check
        enable :change_commit_committer_check
        enable :read_commit_committer_name_check
        enable :change_commit_committer_name_check
        enable :read_reject_unsigned_commits
        enable :change_reject_unsigned_commits
        enable :change_reject_non_dco_commits
      end

      rule { ~push_rules_available }.policy do
        prevent :change_push_rules
      end

      rule { ~commit_committer_check_available }.policy do
        prevent :read_commit_committer_check
        prevent :change_commit_committer_check
      end

      rule { ~commit_committer_name_check_available }.policy do
        prevent :read_commit_committer_name_check
        prevent :change_commit_committer_name_check
      end

      rule { ~reject_unsigned_commits_available }.policy do
        prevent :read_reject_unsigned_commits
        prevent :change_reject_unsigned_commits
      end

      rule { ~reject_non_dco_commits_available }.policy do
        prevent :change_reject_non_dco_commits
      end

      rule { owner | reporter | internal_access | public_project }.enable :build_read_project

      rule { ~admin & owner & owner_cannot_destroy_project }.prevent :remove_project

      rule { user_banned_from_namespace }.prevent_all

      condition(:needs_new_sso_session) do
        ::Gitlab::Auth::GroupSaml::SsoEnforcer.access_restricted?(user: @user, resource: subject)
      end

      # NOTE: This condition does not use :subject scope because it needs to be evaluated for each request,
      # as the request IP can change
      condition(:ip_enforcement_prevents_access) do
        !::Gitlab::IpRestriction::Enforcer.new(subject.group).allows_current_ip? if subject.group
      end

      condition(:owner_cannot_destroy_project, scope: :global) do
        ::Gitlab::CurrentSettings.current_application_settings
          .default_project_deletion_protection
      end

      rule { custom_role_enables_archive_project }.policy do
        enable :archive_project
      end

      rule { custom_role_enables_remove_project }.policy do
        enable :remove_project
      end

      rule { can?(:admin_project) | can?(:archive_project) | can?(:remove_project) | can?(:admin_compliance_framework) }.policy do
        enable :view_edit_page
      end

      rule { needs_new_sso_session }.policy do
        prevent :read_project
      end

      rule { ip_enforcement_prevents_access & ~admin & ~auditor }.policy do
        prevent_all
      end

      rule { locked_approvers_rules }.policy do
        prevent :modify_approvers_rules
      end

      rule { locked_merge_request_author_setting }.policy do
        prevent :modify_merge_request_author_setting
      end

      rule { locked_merge_request_committer_setting }.policy do
        prevent :modify_merge_request_committer_setting
      end

      rule { issue_analytics_enabled }.enable :read_issue_analytics

      rule { can?(:read_merge_request) & code_review_analytics_enabled }.enable :read_code_review_analytics

      rule { (admin | reporter) & dora4_analytics_available }
        .enable :read_dora4_analytics

      rule { (admin | reporter) & project_merge_request_analytics_available }
        .enable :read_project_merge_request_analytics

      rule { admin | reporter }.enable :read_ai_analytics

      rule { combined_project_analytics_dashboards_enabled }.enable :read_combined_project_analytics_dashboards

      rule { can?(:read_project) & requirements_available }.enable :read_requirement

      rule { requirements_available & (reporter | admin) }.policy do
        enable :create_requirement
        enable :create_requirement_test_report
        enable :admin_requirement
        enable :update_requirement
        enable :import_requirements
        enable :export_requirements
      end

      rule { requirements_available & (owner | admin) }.enable :destroy_requirement

      rule { quality_management_available & can?(:reporter_access) & can?(:create_issue) }.enable :create_test_case

      rule { compliance_framework_available & can?(:owner_access) }.enable :admin_compliance_framework

      rule { status_page_available & can?(:owner_access) }.enable :mark_issue_for_publication
      rule { status_page_available & can?(:developer_access) }.enable :publish_status_page

      rule { google_cloud_support_available & can?(:maintainer_access) }.policy do
        enable :read_runner_cloud_provisioning_info
        enable :provision_cloud_runner
      end
      rule { google_cloud_support_available & can?(:reporter_access) }.enable :read_google_cloud_artifact_registry
      rule { google_cloud_support_available & can?(:maintainer_access) }.enable :admin_google_cloud_artifact_registry

      rule { hidden }.policy do
        prevent :download_code
        prevent :build_download_code
      end

      rule { read_only }.policy do
        prevent(*readonly_abilities)

        readonly_features.each do |feature|
          prevent(*create_update_admin(feature))
        end
      end

      rule { auditor | can?(:developer_access) }.enable :add_project_to_instance_security_dashboard

      rule { (admin | maintainer) & group_merge_request_approval_settings_enabled }.policy do
        enable :admin_merge_request_approval_settings
      end

      rule { custom_role_enables_read_code }.enable :read_code

      rule { custom_role_enables_read_vulnerability }.policy do
        enable :access_security_and_compliance
        enable :read_vulnerability
        enable :read_security_resource
        enable :create_vulnerability_export
      end

      rule { custom_role_enables_admin_merge_request }.policy do
        enable :create_merge_request_from
        enable :read_merge_request
        enable :admin_merge_request
        enable :download_code # required to negate https://gitlab.com/gitlab-org/gitlab/-/blob/3061d30d9b3d6d4c4dd5abe68bc1e4a8a93c7966/app/policies/project_policy.rb#L603-607
      end

      rule { custom_role_enables_admin_terraform_state }.policy do
        enable :read_terraform_state
        enable :admin_terraform_state
      end

      rule { custom_role_enables_admin_vulnerability }.policy do
        enable :admin_vulnerability
      end

      rule { custom_role_enables_read_dependency & dependency_scanning_enabled }.policy do
        enable :access_security_and_compliance
        enable :read_dependency
      end

      rule { custom_role_enables_admin_compliance_framework & compliance_framework_available }.policy do
        enable :admin_compliance_framework
      end

      rule { custom_role_enables_manage_deploy_tokens }.policy do
        enable :manage_deploy_tokens
        enable :read_deploy_token
        enable :create_deploy_token
        enable :destroy_deploy_token
      end

      rule { can?(:create_issue) & okrs_enabled }.policy do
        enable :create_objective
        enable :create_key_result
      end

      rule { suggested_reviewers_bot & suggested_reviewers_available & resource_access_token_feature_available & resource_access_token_creation_allowed }.policy do
        enable :admin_project_member
        enable :create_resource_access_tokens
      end

      rule { custom_role_enables_manage_project_access_tokens & resource_access_token_feature_available & resource_access_token_creation_allowed }.policy do
        enable :read_resource_access_tokens
        enable :create_resource_access_tokens
        enable :destroy_resource_access_tokens
        enable :manage_resource_access_tokens
      end

      rule { custom_role_enables_manage_merge_request_settings }.policy do
        enable :manage_merge_request_settings
        enable :edit_approval_rule
        enable :modify_approvers_rules
        enable :modify_merge_request_author_setting
        enable :modify_merge_request_committer_setting
      end

      rule { can?(:manage_merge_request_settings) & target_branch_rules_available }.policy do
        enable :admin_target_branch_rule
      end

      rule { can?(:manage_merge_request_settings) & group_merge_request_approval_settings_enabled }.policy do
        enable :admin_merge_request_approval_settings
      end

      rule { security_policy_bot }.policy do
        enable :create_pipeline
        enable :create_bot_pipeline
        enable :build_download_code
      end

      rule do
        fill_in_merge_request_template_enabled & can?(:create_merge_request_in)
      end.enable :fill_in_merge_request_template

      rule do
        summarize_new_merge_request_enabled & can?(:create_merge_request_in)
      end.enable :summarize_new_merge_request

      rule do
        generate_description_enabled & can?(:create_issue)
      end.enable :generate_description

      rule { target_branch_rules_available & maintainer }.policy do
        enable :admin_target_branch_rule
      end

      rule { target_branch_rules_available }.policy do
        enable :read_target_branch_rule
      end

      rule do
        (maintainer | owner | admin) & pages_multiple_versions_available
      end.enable :pages_multiple_versions

      rule { can?(:reporter_access) & tracing_enabled }.policy do
        enable :read_tracing
      end

      rule { can?(:reporter_access) & observability_metrics_enabled }.policy do
        enable :read_observability_metrics
      end

      rule { can?(:reporter_access) & observability_logs_enabled }.policy do
        enable :read_observability_logs
      end

      rule { ci_cancellation_maintainers_only & ~can?(:maintainer_access) }.policy do
        prevent :cancel_pipeline
        prevent :cancel_build
      end

      rule { ci_cancellation_no_one }.policy do
        prevent :cancel_pipeline
        prevent :cancel_build
      end

      rule { guest | admin }.enable :read_limit_alert

      rule { ai_available & generate_cube_query_enabled }.enable :generate_cube_query

      rule { guest & agent_registry_enabled }.policy do
        enable :read_ai_agents
      end

      rule { reporter & agent_registry_enabled }.policy do
        enable :write_ai_agents
      end

      rule { can?(:read_project) & chat_allowed_for_parent_group & chat_available_for_user }.policy do
        enable :access_duo_chat
      end

      rule { can?(:read_project) & duo_features_enabled }.enable :access_duo_features

      desc "Group has saved replies support"
      condition(:supports_saved_replies) do
        @subject.supports_saved_replies?
      end

      rule { supports_saved_replies & developer }.policy do
        enable :read_saved_replies
        enable :create_saved_replies
        enable :destroy_saved_replies
        enable :update_saved_replies
      end

      condition(:pre_receive_secret_detection_available) do
        ::Gitlab::CurrentSettings.gitlab_dedicated_instance? || ::Feature.enabled?(:pre_receive_secret_detection_push_check, @subject)
      end

      rule { pre_receive_secret_detection_available & can?(:maintainer_access) }.policy do
        enable :enable_pre_receive_secret_detection
      end

      condition(:container_scanning_for_registry_available) do
        ::Feature.enabled?(:container_scanning_for_registry, @subject)
      end

      rule { container_scanning_for_registry_available & can?(:maintainer_access) }.policy do
        enable :enable_container_scanning_for_registry
      end

      rule { custom_role_enables_admin_web_hook }.policy do
        enable :read_web_hook
        enable :admin_web_hook
      end

      with_scope :subject
      condition(:runner_performance_insights_available) do
        @subject.group&.licensed_feature_available?(:runner_performance_insights_for_namespace)
      end

      with_scope :global
      condition(:clickhouse_main_database_available) do
        ::Gitlab::ClickHouse.configured?
      end
    end

    override :lookup_access_level!
    def lookup_access_level!
      return ::Gitlab::Access::NO_ACCESS if needs_new_sso_session?
      return ::Gitlab::Access::REPORTER if security_bot?

      super
    end

    # Available in Core for self-managed but only paid for .com to prevent abuse
    override :resource_access_token_create_feature_available?
    def resource_access_token_create_feature_available?
      return false unless resource_access_token_feature_available?
      return super unless ::Gitlab.com?

      namespace = project.namespace
      namespace.licensed_feature_available?(:resource_access_token)
    end

    override :resource_access_token_feature_available?
    def resource_access_token_feature_available?
      return false if ::Gitlab::CurrentSettings.personal_access_tokens_disabled?

      super
    end
  end
end
