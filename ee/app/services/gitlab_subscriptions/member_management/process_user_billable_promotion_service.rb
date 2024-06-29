# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    class ProcessUserBillablePromotionService < BaseService
      include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils

      FAILED_TO_APPLY_PROMOTIONS = 'FAILED_TO_APPLY_PROMOTIONS'

      attr_reader :current_user

      def initialize(current_user, user, status)
        @current_user = current_user
        @user = user
        @status = status
      end

      def execute
        return error('Unauthorized') unless
          current_user.present? && promotion_management_applicable? && current_user.can_admin_all_resources?

        apply_member_approvals
        success
      rescue ActiveRecord::RecordInvalid
        error(FAILED_TO_APPLY_PROMOTIONS)
      end

      private

      attr_reader :user, :status

      def apply_member_approvals
        ::Members::MemberApproval.pending_member_approvals_for_user(user.id).each do |member_approval|
          member_approval.update!(status: status)
        end
      end

      def success
        ServiceResponse.success(payload: {
          user: user,
          status: status
        })
      end

      def error(message)
        ServiceResponse.error(message: message)
      end
    end
  end
end
