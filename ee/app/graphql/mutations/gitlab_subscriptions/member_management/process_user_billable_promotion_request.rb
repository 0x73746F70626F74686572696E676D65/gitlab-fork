# frozen_string_literal: true

module Mutations
  module GitlabSubscriptions
    module MemberManagement
      class ProcessUserBillablePromotionRequest < BaseMutation
        graphql_name 'ProcessUserBillablePromotionRequest'

        include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils

        argument :user_id, ::Types::GlobalIDType[::User],
          required: true, description: 'Global ID of user to be promoted.'

        argument :status, EE::Types::GitlabSubscriptions::MemberManagement::MemberApprovalStatusEnum,
          required: true,
          description: 'Status for the member approval request (approved, denied, pending).'

        field :result, EE::Types::GitlabSubscriptions::MemberManagement::UserPromotionStatusEnum,
          null: true,
          description: 'Status of the user promotion process (success, partial_success, failed).'

        def resolve(user_id:, status:)
          raise_resource_not_available_error! unless
            promotion_management_applicable? && current_user.can_admin_all_resources?

          user = ::Gitlab::Graphql::Lazy.force(GitlabSchema.find_by_gid(user_id))

          result = ::GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService
                       .new(current_user, user, status).execute

          return { result: :success, errors: [] } if result.success?

          { result: :failed, errors: result.errors }
        end
      end
    end
  end
end
