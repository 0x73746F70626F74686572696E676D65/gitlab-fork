# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    class QueueNonBillableToBillableService < BaseService
      include ::GitlabSubscriptions::MemberManagement::PromotionManagementUtils
      include ::Gitlab::Utils::StrongMemoize

      def initialize(current_user:, params:, users: nil, members: nil, source: nil)
        @current_user = current_user
        assign_users_members_and_source(users, members, source, params)
        source_namespace
        @user_ids = @users.map(&:id)
        @params = params
      end

      def execute
        return success(users, members) unless promotion_management_required?

        sanitize_access_level_and_member_role_id

        return success(users, members) unless non_billable_to_billable_role_change?

        non_billable_to_billable_users, billable_users = partition_non_billable_and_billable_users
        return success(users, members) if non_billable_to_billable_users.empty?

        response = queue_non_billable_to_billable_users_for_approval(non_billable_to_billable_users)

        billable_members = billable_members(billable_users)
        non_billable_to_billable_members = build_non_billable_to_billable_members_with_service_errors(
          non_billable_to_billable_users, response.error?
        )

        return error(billable_users, billable_members, non_billable_to_billable_members) if response.error?

        success(
          billable_users, billable_members, non_billable_to_billable_members,
          response.payload[:users_queued_for_approval]
        )
      end

      private

      attr_accessor :users, :user_ids, :members, :existing_members_hash, :params, :new_access_level,
        :source, :member_role_id

      def source_namespace
        case source
        when ::Group then source
        when ::Project then source.project_namespace
        else
          raise ArgumentError, 'Invalid source. Source should be either Group or Project.'
        end
      end
      strong_memoize_attr :source_namespace

      def assign_users_members_and_source(users, members, source, params)
        @source = source || params[:source]

        if users
          @users = users
          @existing_members_hash = params[:existing_members] || {}
          @members = existing_members_hash.values
        elsif members
          @members = members
          @users = members.map(&:user)
          @existing_members_hash = members.index_by(&:user_id)
          @source ||= members.first.source
        else
          raise ArgumentError, 'Invalid argument. Either members or users should be passed'
        end
      end

      def sanitized_params
        sanitized_params = params.slice(:access_level, :expires_at, :member_role_id)
        sanitized_params[:access_level] = new_access_level
        sanitized_params[:existing_members_hash] = existing_members_hash
        sanitized_params[:source_namespace] = source_namespace

        sanitized_params
      end

      def queue_non_billable_to_billable_users_for_approval(non_billable_to_billable_users)
        GitlabSubscriptions::MemberManagement::QueueMembersApprovalService
          .new(non_billable_to_billable_users, current_user, sanitized_params)
          .execute
      end

      def sanitize_access_level_and_member_role_id
        self.new_access_level = params[:access_level]

        unless custom_role_feature_enabled?
          params.delete(:member_role_id)
          return
        end

        member_role = MemberRole.find_by_id(params[:member_role_id])
        return unless member_role

        self.member_role_id = member_role.id
        self.new_access_level = member_role.base_access_level if new_access_level.nil?
      end

      def promotion_management_required?
        return false if current_user.can_admin_all_resources?

        promotion_management_applicable?
      end

      def non_billable_to_billable_role_change?
        new_access_level.present? &&
          promotion_management_required_for_role?(
            new_access_level: new_access_level,
            member_role_id: member_role_id
          )
      end

      def custom_role_feature_enabled?
        ::License.feature_available?(:custom_roles)
      end

      def build_non_billable_to_billable_members_with_service_errors(non_billable_to_billable_users, error)
        message = if error
                    "Invalid record while queuing users for approval."
                  else
                    "Request Queued For Admin Approval."
                  end

        # Build members with service errors to pass back to consumers
        # as we wont be updating/adding these members until Admin Approval
        non_billable_to_billable_users.map do |user|
          member = ::Members::StandardMemberBuilder.new(source, user, existing_members_hash).execute
          member.access_level = new_access_level
          member.member_role_id = member_role_id

          member.errors.add(:base, message)

          member
        end
      end

      def partition_non_billable_and_billable_users
        non_billable_to_billable_users = GitlabSubscriptions::MemberManagement::SelfManaged::NonBillableUsersFinder
                               .new(current_user, user_ids).execute

        users.partition { |user| non_billable_to_billable_users.include?(user) }
      end

      def billable_members(billable_users)
        members.select { |member| billable_users.include?(member.user) }
      end

      def success(
        billable_users, billable_members, non_billable_to_billable_members = [], users_queued_for_promotion = []
      )
        ServiceResponse.success(payload: {
          billable_users: billable_users,
          billable_members: billable_members,
          non_billable_to_billable_members: non_billable_to_billable_members,
          users_queued_for_promotion: users_queued_for_promotion
        })
      end

      def error(billable_users, billable_members, non_billable_to_billable_members)
        ServiceResponse.error(
          message: "Invalid record while enqueuing users for approval",
          payload: {
            users: users,
            members: members,
            billable_users: billable_users,
            billable_members: billable_members,
            non_billable_to_billable_members: non_billable_to_billable_members
          }.compact
        )
      end
    end
  end
end
