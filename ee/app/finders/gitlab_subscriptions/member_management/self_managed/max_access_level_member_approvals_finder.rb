# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    module SelfManaged
      class MaxAccessLevelMemberApprovalsFinder
        include GitlabSubscriptions::MemberManagement::PromotionManagementUtils

        def initialize(current_user)
          @current_user = current_user
        end

        def execute
          model = ::Members::MemberApproval
          return model.none unless promotion_management_applicable?
          return model.none unless current_user.can_admin_all_resources?

          model.pending_member_approvals_with_max_new_access_level
        end

        private

        attr_reader :current_user
      end
    end
  end
end
