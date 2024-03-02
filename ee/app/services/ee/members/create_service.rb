# frozen_string_literal: true

module EE
  module Members
    module CreateService
      extend ::Gitlab::Utils::Override

      override :initialize
      def initialize(*args)
        super

        @added_member_ids_with_users = []
      end

      private

      attr_accessor :added_member_ids_with_users

      def create_params
        top_level_group = source.root_ancestor

        return super unless top_level_group.custom_roles_enabled?

        super.merge(member_role_id: params[:member_role_id])
      end

      def validate_invitable!
        super

        check_membership_lock!
        check_quota!
        check_seats!
      end

      def check_quota!
        return unless invite_quota_exceeded?

        message = format(
          s_("AddMember|Invite limit of %{daily_invites} per day exceeded."),
          daily_invites: source.actual_limits.daily_invites
        )
        raise ::Members::CreateService::TooManyInvitesError, message
      end

      def check_membership_lock!
        return unless source.membership_locked?

        @membership_locked = true # rubocop:disable Gitlab/ModuleWithInstanceVariables
        raise ::Members::CreateService::MembershipLockedError
      end

      def check_seats!
        root_namespace = source.root_ancestor

        return unless root_namespace.block_seat_overages? && !root_namespace.seats_available_for?(invites)

        raise ::Members::CreateService::SeatLimitExceededError, s_('AddMember|Not enough seats for this many users.')
      end

      def invite_quota_exceeded?
        return if source.actual_limits.daily_invites == 0

        invite_count = ::Member.invite.created_today.in_hierarchy(source).count

        source.actual_limits.exceeded?(:daily_invites, invite_count + invites.count)
      end

      override :after_add_hooks
      def after_add_hooks
        super

        return unless execute_notification_worker?

        ::Namespaces::FreeUserCap::GroupOverLimitNotificationWorker
          .perform_async(source.id, added_member_ids_with_users)
      end

      def execute_notification_worker?
        ::Namespaces::FreeUserCap.dashboard_limit_enabled? &&
          source.is_a?(Group) && # only ever an invited group's members could affect this
          added_member_ids_with_users.any?
      end

      def after_execute(member:)
        super

        append_added_member_ids_with_users(member: member)
        log_audit_event(member: member)
      end

      def append_added_member_ids_with_users(member:)
        return unless ::Namespaces::FreeUserCap.dashboard_limit_enabled?
        return unless new_and_attached_to_user?(member: member)

        added_member_ids_with_users << member.id
      end

      def new_and_attached_to_user?(member:)
        # Only members attached to users can possibly affect the user count.
        # If the member was merely updated, they won't affect a change to the user count.
        member.user_id && member.previously_new_record?
      end

      def log_audit_event(member:)
        audit_context = {
          name: 'member_created',
          author: current_user || ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)'),
          scope: member.source,
          target: member.user || ::Gitlab::Audit::NullTarget.new,
          target_details: member.user&.name || 'Created Member',
          message: 'Membership created',
          additional_details: {
            add: 'user_access',
            as: member.human_access_labeled,
            member_id: member.id
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
