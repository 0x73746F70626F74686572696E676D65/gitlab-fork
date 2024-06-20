# frozen_string_literal: true

# EE-specific code related to protected branch/tag access levels.
#
# Note: Don't directly include this concern into a model class.
# Instead, include `ProtectedBranchAccess` or `ProtectedTagAccess`, which in
# turn include this concern. A number of methods here depend on
# `ProtectedRefAccess` being next up in the ancestor chain.

module EE
  module ProtectedRefAccess
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    module Scopes
      extend ActiveSupport::Concern

      included do
        belongs_to :user
        belongs_to :group

        protected_ref_fk = "#{module_parent.model_name.singular}_id"
        with_options uniqueness: { scope: protected_ref_fk, allow_nil: true } do
          validates :group_id
          validates :user_id
        end

        # Skip validations when importing
        # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/108342
        with_options unless: :importing? do
          validates :group_id, :user_id, absence: true, if: :user_and_group_not_assignable?

          validates :group, presence: true, if: %i[group_id user_or_group_assignable?]
          validates :user, presence: true, if: %i[user_id user_or_group_assignable?]

          validate :validate_group_membership, if: %i[group user_or_group_assignable?]
          validate :validate_user_membership, if: %i[user user_or_group_assignable?]
        end

        scope :by_user, ->(user) { where(user_id: user) }
        scope :by_group, ->(group) { where(group_id: group) }
        scope :for_user, -> { where.not(user_id: nil) }
        scope :for_group, -> { where.not(group_id: nil) }
      end
    end

    class_methods do
      def non_role_types
        super.concat(%i[user group])
      end
    end

    override :type
    def type
      return :user if user_id || user
      return :group if group_id || group

      super
    end

    override :humanize
    def humanize
      return humanize_user if user?
      return humanize_group if group?

      super
    end

    override :check_access
    def check_access(current_user, current_project = project)
      super do
        break current_user.id == user_id if user?
        break group_access_allowed?(current_user) if group?

        yield if block_given?
      end
    end

    private

    def humanize_user
      user&.name || 'User'
    end

    def humanize_group
      group&.name || 'Group'
    end

    def group_access_allowed?(current_user)
      group.has_user?(current_user)
    end

    def user?
      type == :user
    end

    def group?
      type == :group
    end

    # We don't need to validate the license if this access applies to a role.
    #
    # If it applies to a user/group we can only skip validation `nil`-validation
    # if the feature is available
    def user_or_group_assignable?
      !role? && project&.feature_available?(:protected_refs_for_users)
    end

    def user_and_group_not_assignable?
      !user_or_group_assignable?
    end

    def validate_group_membership
      return if project.project_group_links.where(group: group).exists?

      errors.add(:group, 'does not have access to the project')
    end

    def validate_user_membership
      return if project.member?(user)

      errors.add(:user, 'is not a member of the project')
    end
  end
end
