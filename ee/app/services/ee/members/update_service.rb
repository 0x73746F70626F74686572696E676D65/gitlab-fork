# frozen_string_literal: true

module EE
  module Members
    module UpdateService
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils

      override :execute
      def execute(members, permission: :update)
        return super unless non_admin_and_member_promotion_management_enabled? && members.present?

        members = Array.wrap(members)
        validate_update_permission!(members, permission)

        service_response = GitlabSubscriptions::MemberManagement::QueueNonBillableToBillableService.new(
          current_user: current_user,
          members: members,
          params: params).execute

        if service_response.error?
          errored_members = service_response.payload[:non_billable_to_billable_members]
          return prepare_response(errored_members)
        end

        billable_members = service_response.payload[:billable_members]
        members_queued_for_approval = service_response.payload[:users_queued_for_promotion]

        update_member_response = super(billable_members, permission: permission)
        return update_member_response if update_member_response[:status] == :error

        update_member_response.merge(members_queued_for_approval: members_queued_for_approval)
      end

      override :after_execute
      def after_execute(action:, old_access_level:, old_expiry:, member:)
        super

        log_audit_event(old_access_level: old_access_level, old_expiry: old_expiry, member: member)
      end

      private

      override :has_update_permissions?
      def has_update_permissions?(member, permission)
        super && !member_role_too_high?(member)
      end

      def member_role_too_high?(member)
        return false unless params[:access_level] # we don't update access_level

        member.prevent_role_assignement?(current_user, params.merge(current_access_level: member.access_level))
      end

      def non_admin_and_member_promotion_management_enabled?
        return false if current_user.can_admin_all_resources?

        promotion_management_applicable?
      end

      def validate_update_permission!(members, permission)
        return if members.all? { |member| has_update_permissions?(member, permission) }

        raise ::Gitlab::Access::AccessDeniedError
      end

      override :update_member
      def update_member(member, permission)
        handle_member_role_assignement(member) if params.key?(:member_role_id)

        super
      end

      def handle_member_role_assignement(member)
        top_level_group = member.source.root_ancestor

        params.delete(:member_role_id) unless top_level_group.custom_roles_enabled?

        return unless params[:member_role_id]

        member_role = MemberRoles::RolesFinder.new(current_user, { id: params[:member_role_id] }).execute.first

        unless member_role
          member.errors.add(:member_role, "not found")
          raise ActiveRecord::RecordInvalid
        end

        return if params[:access_level]

        params[:access_level] ||= member_role.base_access_level
      end

      def log_audit_event(old_access_level:, old_expiry:, member:)
        audit_context = {
          name: 'member_updated',
          author: current_user || ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)'),
          scope: member.source,
          target: member.user || ::Gitlab::Audit::NullTarget.new,
          target_details: member.user&.name || 'Updated Member',
          message: 'Membership updated',
          additional_details: {
            change: 'access_level',
            from: old_access_level,
            to: member.human_access_labeled,
            expiry_from: old_expiry,
            expiry_to: member.expires_at,
            as: member.human_access_labeled,
            member_id: member.id
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
