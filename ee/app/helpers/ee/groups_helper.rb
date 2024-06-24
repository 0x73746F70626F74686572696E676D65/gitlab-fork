# frozen_string_literal: true

module EE
  module GroupsHelper
    extend ::Gitlab::Utils::Override
    include ::GitlabSubscriptions::CodeSuggestionsHelper

    def size_limit_message_for_group(group)
      show_lfs = group.lfs_enabled? ? 'including LFS files' : ''

      "Max size for repositories within this group #{show_lfs}. Can be overridden inside each project. For no limit, enter 0. To inherit the global value, leave blank."
    end

    override :subgroup_creation_data
    def subgroup_creation_data(group)
      super.merge({
        identity_verification_required: current_user.requires_identity_verification_to_create_group?(group).to_s,
        identity_verification_path: identity_verification_path
      })
    end

    override :show_prevent_inviting_groups_outside_hierarchy_setting?
    def show_prevent_inviting_groups_outside_hierarchy_setting?(group)
      super && !group.block_seat_overages?
    end

    override :can_admin_service_accounts?
    def can_admin_service_accounts?(group)
      Ability.allowed?(current_user, :admin_service_accounts, group)
    end

    override :remove_group_message
    def remove_group_message(group)
      return super unless group.licensed_feature_available?(:adjourned_deletion_for_projects_and_groups)
      return super if group.marked_for_deletion?
      return super unless group.adjourned_deletion?

      date = permanent_deletion_date_formatted(group, Time.now.utc)

      _("The contents of this group, its subgroups and projects will be permanently deleted after %{deletion_adjourned_period} days on %{date}. After this point, your data cannot be recovered.") %
        { date: date, deletion_adjourned_period: deletion_adjourned_period }
    end

    def immediately_remove_group_message(group)
      message = _('This action will %{strongOpen}permanently remove%{strongClose} %{codeOpen}%{group}%{codeClose} %{strongOpen}immediately%{strongClose}.')

      ERB::Util.html_escape(message) % {
        group: group.path,
        strongOpen: '<strong>'.html_safe,
        strongClose: '</strong>'.html_safe,
        codeOpen: '<code>'.html_safe,
        codeClose: '</code>'.html_safe
      }
    end

    def permanent_deletion_date_formatted(group, date)
      group.permanent_deletion_date(date).strftime('%F')
    end

    def deletion_adjourned_period
      ::Gitlab::CurrentSettings.deletion_adjourned_period
    end

    def show_discover_group_security?(group)
      !!current_user &&
        ::Gitlab.com? &&
        !group.licensed_feature_available?(:security_dashboard) &&
        can?(current_user, :admin_group, group)
    end

    def show_group_activity_analytics?
      can?(current_user, :read_group_activity_analytics, @group)
    end

    def show_product_purchase_success_alert?
      !params[:purchased_product].blank?
    end

    def show_user_cap_alert?
      root_namespace = @group.root_ancestor

      return false unless root_namespace.present? &&
        can?(current_user, :admin_group, root_namespace) &&
        root_namespace.user_cap_available? &&
        root_namespace.namespace_settings.present?

      root_namespace.user_cap_enabled?
    end

    def pending_members_link
      link_to('', pending_members_group_usage_quotas_path(@group.root_ancestor))
    end

    def group_seats_usage_quota_app_data(group)
      {
        namespace_id: group.id,
        namespace_name: group.name,
        is_public_namespace: group.public?.to_s,
        full_path: group.full_path,
        seat_usage_export_path: group_seat_usage_path(group, format: :csv),
        add_seats_href: add_seats_url(group),
        has_no_subscription: group.has_free_or_no_subscription?.to_s,
        max_free_namespace_seats: ::Namespaces::FreeUserCap.dashboard_limit,
        explore_plans_path: group_billings_path(group),
        enforcement_free_user_cap_enabled: ::Namespaces::FreeUserCap::Enforcement.new(group).enforce_cap?.to_s
      }
    end

    def code_suggestions_usage_app_data(group)
      {
        full_path: group.full_path,
        group_id: group.id,
        add_duo_pro_href: duo_pro_url(group),
        duo_pro_bulk_user_assignment_available: duo_pro_bulk_user_assignment_available?(group).to_s
      }.merge(duo_pro_trial_link(group))
    end

    def duo_pro_trial_link(group)
      if group.subscription_add_on_purchases.for_gitlab_duo_pro.none?
        return { duo_pro_trial_href: new_trials_duo_pro_path(namespace_id: group.id) }
      end

      {}
    end

    def product_analytics_usage_quota_app_data(group)
      {
        namespace_path: group.full_path,
        empty_state_illustration_path: image_path('illustrations/empty-state/empty-dashboard-md.svg'),
        product_analytics_enabled: ::Gitlab::CurrentSettings.product_analytics_enabled?.to_s
      }
    end

    def show_usage_quotas_tab?(group, tab)
      case tab
      when :seats
        License.feature_available?(:seat_usage_quotas)
      when :code_suggestions
        gitlab_com_subscription? &&
          gitlab_duo_available?(group) &&
          (!group.has_free_or_no_subscription? || group.subscription_add_on_purchases.active.for_gitlab_duo_pro.any?) &&
          License.feature_available?(:code_suggestions)
      when :pipelines
        Ability.allowed?(current_user, :admin_ci_minutes, group) &&
          License.feature_available?(:pipelines_usage_quotas)
      when :transfer
        ::Feature.enabled?(:data_transfer_monitoring, group) &&
          License.feature_available?(:transfer_usage_quotas)
      when :product_analytics
        License.feature_available?(:product_analytics_usage_quotas)
      else
        false
      end
    end

    def saml_sso_settings_generate_helper_text(display_none:, text:)
      content_tag(:span, text, class: ['js-helper-text', 'gl-clearfix', ('gl-display-none' if display_none)])
    end

    def group_transfer_app_data(group)
      {
        full_path: group.full_path
      }
    end
  end
end
