# frozen_string_literal: true

module EE
  module ProjectsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include GeoInstrumentation
      include GitlabSubscriptions::SeatCountAlert

      before_action :log_download_export_audit_event, only: [:download_export]
      before_action :log_archive_audit_event, only: [:archive]
      before_action :log_unarchive_audit_event, only: [:unarchive]

      before_action only: :show do
        @seat_count_data = generate_seat_count_alert_data(@project)
      end

      before_action do
        push_licensed_feature(:remote_development)
      end

      feature_category :groups_and_projects, [:restore]
    end

    def restore
      return access_denied! unless can?(current_user, :remove_project, project)

      result = ::Projects::RestoreService.new(project, current_user, {}).execute

      if result[:status] == :success
        flash[:notice] = format(_("Project '%{project_name}' has been successfully restored."), project_name: project.full_name)

        redirect_to(edit_project_path(project))
      else
        flash.now[:alert] = result[:message]

        render_edit
      end
    end

    override :destroy
    def destroy
      return super unless License.feature_available?(:adjourned_deletion_for_projects_and_groups)
      return super unless project.adjourned_deletion_configured?
      return super if project.marked_for_deletion_at? && params[:permanently_delete].present?

      return access_denied! unless can?(current_user, :remove_project, project)

      result = ::Projects::MarkForDeletionService.new(project, current_user, {}).execute

      if result[:status] == :success
        date = permanent_deletion_date_formatted(project, project.marked_for_deletion_at)
        flash[:notice] = _("Project '%{project_name}' will be deleted on %{date}") % { date: date, project_name: project.full_name }

        if project.licensed_feature_available?(:adjourned_deletion_for_projects_and_groups)
          redirect_to(project_path(project), status: :found)
        else
          redirect_to dashboard_projects_path, status: :found
        end

      else
        flash.now[:alert] = result[:message]

        render_edit
      end
    end

    override :project_feature_attributes
    def project_feature_attributes
      super + [:requirements_access_level]
    end

    override :project_params_attributes
    def project_params_attributes
      super + project_params_ee
    end

    override :custom_import_params
    def custom_import_params
      custom_params = super
      ci_cd_param   = params.dig(:project, :ci_cd_only) || params[:ci_cd_only]

      custom_params[:ci_cd_only] = ci_cd_param if ci_cd_param == 'true'
      custom_params
    end

    override :active_new_project_tab
    def active_new_project_tab
      project_params[:ci_cd_only] == 'true' ? 'ci_cd_only' : super
    end

    private

    override :project_setting_attributes
    def project_setting_attributes
      attributes = %i[
        prevent_merge_without_jira_issue
        cve_id_request_enabled
        product_analytics_data_collector_host
        cube_api_base_url
        cube_api_key
        product_analytics_configurator_connection_string
      ]

      if project&.licensed_feature_available?(:external_status_checks)
        attributes << :only_allow_merge_if_all_status_checks_passed
      end

      super + attributes
    end

    def project_params_ee
      attrs = %i[
        approvals_before_merge
        approver_group_ids
        approver_ids
        issues_template
        merge_requests_template
        repository_size_limit
        reset_approvals_on_push
        ci_cd_only
        use_custom_template
        require_password_to_approve
        group_with_project_templates_id
      ]

      attrs << :merge_pipelines_enabled if allow_merge_pipelines_params?
      attrs << :merge_trains_enabled if allow_merge_trains_params?
      attrs << :merge_trains_skip_train_allowed if allow_merge_trains_params?

      attrs += merge_request_rules_params

      if project&.feature_available?(:auto_rollback)
        attrs << :auto_rollback_enabled
      end

      if project&.feature_available?(:project_level_analytics_dashboard)
        attrs << { analytics_dashboards_pointer_attributes: [:id, :target_project_id, :_destroy] }
      end

      if allow_mirror_params?
        attrs + mirror_params
      else
        attrs
      end
    end

    def mirror_params
      %i[
        mirror
        mirror_trigger_builds
      ]
    end

    def allow_mirror_params?
      if @project # rubocop:disable Gitlab/ModuleWithInstanceVariables
        can?(current_user, :admin_mirror, @project) # rubocop:disable Gitlab/ModuleWithInstanceVariables
      else
        ::Gitlab::CurrentSettings.current_application_settings.mirror_available || current_user&.admin?
      end
    end

    def merge_request_rules_params
      attrs = []

      if can?(current_user, :modify_merge_request_committer_setting, project)
        attrs << :merge_requests_disable_committers_approval
      end

      if can?(current_user, :modify_approvers_rules, project)
        attrs << :disable_overriding_approvers_per_merge_request
      end

      if can?(current_user, :modify_merge_request_author_setting, project)
        attrs << :merge_requests_author_approval
      end

      attrs
    end

    def allow_merge_pipelines_params?
      project&.feature_available?(:merge_pipelines)
    end

    def allow_merge_trains_params?
      project&.feature_available?(:merge_trains)
    end

    def log_audit_event(message:, event_type:)
      audit_context = {
        name: event_type,
        author: current_user,
        target: project,
        scope: project,
        message: message,
        ip_address: request.remote_ip
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    def log_download_export_audit_event
      return if current_user.can_admin_all_resources? && ::Gitlab::CurrentSettings.silent_admin_exports_enabled?

      log_audit_event(message: 'Export file download started', event_type: 'project_export_file_download_started')
    end

    def log_archive_audit_event
      log_audit_event(message: 'Project archived', event_type: 'project_archived')
    end

    def log_unarchive_audit_event
      log_audit_event(message: 'Project unarchived', event_type: 'project_unarchived')
    end
  end
end
