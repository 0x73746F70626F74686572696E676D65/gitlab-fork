# frozen_string_literal: true

module EE
  module InviteMembersHelper
    include GitlabSubscriptions::SubscriptionHelper
    extend ::Gitlab::Utils::Override

    override :common_invite_group_modal_data
    def common_invite_group_modal_data(source, _member_class, _is_project)
      super.merge(
        free_user_cap_enabled: ::Namespaces::FreeUserCap::Enforcement.new(source.root_ancestor).enforce_cap?.to_s,
        free_users_limit: ::Namespaces::FreeUserCap.dashboard_limit,
        overage_members_modal_available: overage_members_modal_available.to_s,
        has_gitlab_subscription: gitlab_com_subscription?.to_s
      )
    end

    override :common_invite_modal_dataset
    def common_invite_modal_dataset(source)
      dataset = super

      free_user_cap = ::Namespaces::FreeUserCap::Enforcement.new(source.root_ancestor)

      if source.root_ancestor.trial_active? && free_user_cap.qualified_namespace?
        dataset[:active_trial_dataset] = ::Gitlab::Json.dump(active_trial_dataset(source))
      end

      if free_user_cap.enforce_cap?
        dataset[:users_limit_dataset] = ::Gitlab::Json.dump(
          users_limit_dataset(source, free_user_cap)
        )
      end

      if can?(current_user, :admin_licensed_seat, source.root_ancestor)
        dataset[:add_seats_href] = add_seats_url(source.root_ancestor)
      end

      dataset[:manage_member_roles_path] = manage_member_roles_path(source)
      dataset[:overage_members_modal_available] = overage_members_modal_available.to_s
      dataset[:has_gitlab_subscription] = gitlab_com_subscription?.to_s

      dataset
    end

    def active_trial_dataset(source)
      {
        purchase_path: group_billings_path(source.root_ancestor),
        free_users_limit: ::Namespaces::FreeUserCap.dashboard_limit
      }
    end

    def users_limit_dataset(source, free_user_cap)
      alert_variant =
        if free_user_cap.enforce_cap?
          if free_user_cap.reached_limit?
            ::Namespaces::FreeUserCap::REACHED_LIMIT_VARIANT
          elsif free_user_cap.close_to_dashboard_limit?
            ::Namespaces::FreeUserCap::CLOSE_TO_LIMIT_VARIANT
          end
        end

      {
        alert_variant: alert_variant,
        new_trial_registration_path: new_trial_path(namespace_id: source.root_ancestor.id),
        members_path: group_usage_quotas_path(source.root_ancestor),
        purchase_path: group_billings_path(source.root_ancestor),
        remaining_seats: free_user_cap.remaining_seats,
        free_users_limit: ::Namespaces::FreeUserCap.dashboard_limit
      }
    end

    override :users_filter_data
    def users_filter_data(group)
      root_group = group&.root_ancestor

      return {} unless root_group&.enforced_sso? && root_group.saml_provider&.id

      { users_filter: 'saml_provider_id', filter_id: root_group.saml_provider.id }
    end

    def overage_members_modal_available
      ::Gitlab::Saas.feature_available?(:overage_members_modal)
    end
  end
end
