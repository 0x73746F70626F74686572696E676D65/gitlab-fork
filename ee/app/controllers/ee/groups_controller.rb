# frozen_string_literal: true

module EE
  module GroupsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include PreventForkingHelper
    include ServiceAccessTokenExpirationHelper
    include GroupInviteMembers
    include GitlabSubscriptions::SubscriptionHelper

    prepended do
      include GeoInstrumentation
      include GitlabSubscriptions::SeatCountAlert

      before_action :authorize_remove_group!, only: [:destroy, :restore]
      before_action :check_subscription!, only: [:destroy]

      # for general settings certain features can be enabled via custom roles
      skip_before_action :authorize_admin_group!, only: [:edit, :update]
      before_action :authorize_view_edit_page!, only: [:edit, :update]

      before_action do
        push_frontend_feature_flag(:saas_user_caps_auto_approve_pending_users_on_cap_increase, @group)
      end

      before_action only: :show do
        @seat_count_data = generate_seat_count_alert_data(@group)
      end

      feature_category :groups_and_projects, [:restore]
    end

    override :render_show_html
    def render_show_html
      if redirect_show_path
        redirect_to redirect_show_path, status: :temporary_redirect
      else
        super
      end
    end

    def group_params_attributes
      super + group_params_ee
    end

    override :destroy
    def destroy
      return super unless group.adjourned_deletion?
      return super if group.marked_for_deletion? && ::Gitlab::Utils.to_boolean(params[:permanently_remove])

      result = ::Groups::MarkForDeletionService.new(group, current_user).execute

      if result[:status] == :success
        redirect_to group_path(group),
          status: :found,
          notice: "'#{group.name}' has been scheduled for removal on #{permanent_deletion_date_formatted(group, Time.current.utc)}."
      else
        redirect_to edit_group_path(group), status: :found, alert: result[:message]
      end
    end

    def restore
      return render_404 unless group.marked_for_deletion?

      result = ::Groups::RestoreService.new(group, current_user).execute

      if result[:status] == :success
        redirect_to edit_group_path(group), notice: format(_("Group '%{group_name}' has been successfully restored."), group_name: group.full_name)
      else
        redirect_to edit_group_path(group), alert: result[:message]
      end
    end

    private

    def check_subscription!
      if group.prevent_delete?
        redirect_to edit_group_path(group),
          status: :found,
          alert: _('This group is linked to a subscription')
      end
    end

    # rubocop:disable Metrics/AbcSize -- Reason: The .tap block requires many necessary checks for each parameter.
    def group_params_ee
      [
        :membership_lock,
        :repository_size_limit,
        :new_user_signups_cap
      ].tap do |params_ee|
        params_ee << { insight_attributes: [:id, :project_id, :_destroy] } if current_group&.insights_available?
        params_ee << { analytics_dashboards_pointer_attributes: [:id, :target_project_id, :_destroy] } if current_group&.feature_available?(:group_level_analytics_dashboard)
        params_ee << :file_template_project_id if current_group&.feature_available?(:custom_file_templates_for_namespace)
        params_ee << :custom_project_templates_group_id if current_group&.group_project_template_available?
        params_ee << :ip_restriction_ranges if current_group && current_group.licensed_feature_available?(:group_ip_restriction)
        params_ee << :allowed_email_domains_list if current_group&.feature_available?(:group_allowed_email_domains)
        params_ee << :max_pages_size if can?(current_user, :update_max_pages_size)
        params_ee << :max_personal_access_token_lifetime if current_group&.personal_access_token_expiration_policy_available?
        params_ee << :prevent_forking_outside_group if can_change_prevent_forking?(current_user, current_group)
        params_ee << :service_access_tokens_expiration_enforced if can_change_service_access_tokens_expiration?(current_user, current_group)
        params_ee << :enforce_ssh_certificates if current_group&.ssh_certificates_available?
        params_ee << { value_stream_dashboard_aggregation_attributes: [:enabled] } if can?(current_user, :modify_value_stream_dashboard_settings, current_group)
        params_ee.push(:experiment_features_enabled, :early_access_program_participant) if experiment_settings_allowed?
        params_ee.push(%i[duo_features_enabled lock_duo_features_enabled]) if licensed_ai_features_available?
        params_ee << :disable_personal_access_tokens
        params_ee << :enable_auto_assign_gitlab_duo_pro_seats if allow_update_enable_auto_assign_gitlab_duo_pro_seats?
      end + security_policies_toggle_params
    end
    # rubocop:enable Metrics/AbcSize

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
      ::Feature.enabled?(:auto_assign_gitlab_duo_pro_seats, current_group) && gitlab_com_subscription? && current_group&.root? &&
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

    def redirect_show_path
      strong_memoize(:redirect_show_path) do
        case group_view
        when 'security_dashboard'
          helpers.group_security_dashboard_path(group)
        end
      end
    end

    def group_view
      current_user&.group_view || default_group_view
    end

    def default_group_view
      EE::User::DEFAULT_GROUP_VIEW
    end

    override :successful_creation_hooks
    def successful_creation_hooks
      super

      invite_members(group, invite_source: 'group-creation-page')
    end
  end
end
