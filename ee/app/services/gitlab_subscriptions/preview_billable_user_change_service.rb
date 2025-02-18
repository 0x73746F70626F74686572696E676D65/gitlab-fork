# frozen_string_literal: true

module GitlabSubscriptions
  class PreviewBillableUserChangeService
    include Gitlab::Utils::StrongMemoize

    attr_reader :current_user, :target_namespace, :role, :add_group_id, :add_user_emails, :add_user_ids, :member_role_id

    def initialize(current_user:, target_namespace:, role:, **opts)
      @current_user     = current_user
      @target_namespace = target_namespace
      @role             = role
      @add_group_id     = opts[:add_group_id]    || nil
      @add_user_emails  = opts[:add_user_emails] || []
      @add_user_ids     = opts[:add_user_ids]    || []
      @member_role_id   = opts[:member_role_id]  || nil
    end

    def execute
      {
        success: true,
        data: {
          will_increase_overage: will_increase_overage?,
          new_billable_user_count: new_billable_user_count,
          seats_in_subscription: seats_in_subscription
        }
      }
    end

    private

    def all_added_user_ids
      ids = Set.new

      ids += add_user_ids
      ids += user_ids_from_added_emails
      ids += user_ids_from_added_group

      ids
    end

    def user_ids_from_added_emails
      @user_ids_from_added_emails ||= begin
        return [] if add_user_emails.blank?

        User.by_any_email(add_user_emails).pluck(:id) # rubocop:disable CodeReuse/ActiveRecord
      end
    end

    def user_ids_from_added_group
      return [] if add_group_id.blank?

      group = GroupFinder.new(current_user).execute(id: add_group_id)

      return [] unless group

      group.billed_user_ids[:user_ids]
    end

    def will_increase_overage?
      return false unless reconciliation_enabled?

      new_billable_user_count > current_max_billable_users
    end

    def new_billable_user_count
      @new_billable_user_count ||= begin
        return target_namespace.billable_members_count unless increase_billable_members_count?

        unmatched_added_emails_count = add_user_emails.count - user_ids_from_added_emails.count

        (target_namespace.billed_user_ids[:user_ids].to_set + all_added_user_ids).count + unmatched_added_emails_count
      end
    end

    def increase_billable_members_count?
      return true if role != :guest || !target_namespace.exclude_guests?
      return false unless member_role_id
      return false unless member_role

      (MemberRole.elevating_permissions & member_role.enabled_permissions).present?
    end

    def member_role
      strong_memoize("member_role") do
        MemberRole.find_by_id(member_role_id)
      end
    end

    def seats_in_subscription
      @seats_in_subscription ||= target_namespace.gitlab_subscription&.seats || 0
    end

    def current_max_billable_users
      [target_namespace.billable_members_count, seats_in_subscription].max
    end

    def reconciliation_enabled?
      GitlabSubscriptions::Reconciliations::CheckSeatUsageAlertsEligibilityService.new(
        namespace: target_namespace,
        skip_cached: true
      ).execute
    end
  end
end

GitlabSubscriptions::PreviewBillableUserChangeService.prepend_mod
