# frozen_string_literal: true

module EE
  module MemberEntity
    extend ActiveSupport::Concern

    prepended do
      expose :using_license do |member|
        can?(current_user, :owner_access, group) && member.user&.using_gitlab_com_seat?(group)
      end

      expose :group_sso?, as: :group_sso

      expose :group_managed_account?, as: :group_managed_account

      expose :can_override do |member|
        member.can_override?
      end

      expose :override, as: :is_overridden

      expose :enterprise_user_of_this_group?, as: :enterprise_user_of_this_group

      expose :can_ban?, as: :can_ban
      expose :can_unban?, as: :can_unban

      expose :can_disable_two_factor do |member|
        member.user&.two_factor_enabled? & member.user&.managed_by_user?(current_user, group: group)
      end

      expose :banned do |member|
        member.user.present? && member.user.banned_from_namespace?(group)
      end
    end

    private

    def group
      options[:group]
    end
  end
end
