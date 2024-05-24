# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    class QueueExistingMembersService < BaseService
      include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils

      def initialize(current_user, members, params = {})
        @current_user = current_user
        @members = members
        @params = params

        set_member_access_info
      end

      def execute
        return success(members_to_update: members) unless changes_require_approval?

        process_members_for_approval(members)
      end

      private

      attr_accessor :new_access_level, :member_role_id, :members

      def set_member_access_info
        @new_access_level = params[:access_level]
        @member_role_id = params[:member_role_id]
      end

      def success(members_to_update:, members_queued_for_approval: nil)
        ServiceResponse.success(payload: {
          members_to_update: members_to_update,
          members_queued_for_approval: members_queued_for_approval
        })
      end

      def error(members_requiring_approval)
        ServiceResponse.error(message: "Invalid record while enqueuing members for approval",
          payload: { members: members_requiring_approval })
      end

      def changes_require_approval?
        promotion_management_applicable? && need_approval_for_role_change? && role_change_request?
      end

      def process_members_for_approval(members)
        members = Array.wrap(members)
        members_requiring_approval, members_to_update = partition_members_by_approval_need(members)

        return success(members_to_update: members_to_update) if members_requiring_approval.empty?

        members_queued_for_approval = queue_members_for_approval(members_requiring_approval)
        return error(members_requiring_approval) if members_queued_for_approval.empty?

        success(members_to_update: members_to_update, members_queued_for_approval: members_queued_for_approval)
      end

      def partition_members_by_approval_need(members)
        members.partition do |member|
          promotion_management_required_for_role?(
            new_access_level: new_access_level,
            member_role_id: member_role_id,
            existing_member: member
          )
        end
      end

      def queue_members_for_approval(members_to_queue)
        ::Members::MemberApproval.transaction do
          members_to_queue.map do |member|
            member.queue_for_approval(new_access_level, current_user, member_role_id)
          end
        end
      rescue ActiveRecord::RecordInvalid
        []
      end

      def role_change_request?
        return false if new_access_level.nil? && member_role_id.nil?

        base_access_level = nil

        if member_role_id.present? && custom_role_feature_enabled?
          @member_role_id, base_access_level = get_member_role_id_and_base_access_level
        end

        @new_access_level ||= base_access_level # rubocop:disable Gitlab/PredicateMemoization -- Not memoizing

        @new_access_level.present?
      end

      def get_member_role_id_and_base_access_level
        member_role = MemberRole.find_by_id(member_role_id)

        [member_role&.id, member_role&.base_access_level]
      end

      def need_approval_for_role_change?
        !current_user.can_admin_all_resources?
      end

      def custom_role_feature_enabled?
        ::License.feature_available?(:custom_roles)
      end
    end
  end
end
