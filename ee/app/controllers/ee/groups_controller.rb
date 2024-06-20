# frozen_string_literal: true

module EE
  module GroupsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include GroupInviteMembers

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
