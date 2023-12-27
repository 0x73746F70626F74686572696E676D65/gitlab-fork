# frozen_string_literal: true

module EE
  module GroupMember
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include UsageStatistics

      validate :sso_enforcement, if: -> { group && user }
      validate :group_domain_limitations, if: :group_has_domain_limitations?

      scope :by_group_ids, ->(group_ids) { where(source_id: group_ids) }

      scope :with_ldap_dn, -> do
        joins(user: :identities).where("identities.provider LIKE ?", 'ldap%')
        .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422405')
      end

      scope :with_identity_provider, ->(provider) do
        joins(user: :identities).where(identities: { provider: provider })
      end

      scope :with_saml_identity, ->(provider) do
        joins(user: :identities).where(identities: { saml_provider_id: provider })
        .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422405')
      end

      scope :reporters, -> { where(access_level: ::Gitlab::Access::REPORTER) }
      scope :guests, -> { where(access_level: ::Gitlab::Access::GUEST) }
      scope :non_owners, -> { where("members.access_level < ?", ::Gitlab::Access::OWNER) }
      scope :by_user_id, ->(user_id) { where(user_id: user_id) }

      scope :eligible_approvers_by_groups, ->(groups) do
        where(source_id: groups.pluck(:id), access_level: ::Gitlab::Access::DEVELOPER...)
          .limit(::Security::ScanResultPolicy::APPROVERS_LIMIT)
      end

      attr_accessor :ignore_user_limits
    end

    class_methods do
      def member_of_group?(group, user)
        exists?(group: group, user: user)
      end

      def filter_by_enterprise_users(value)
        subquery =
          ::UserDetail.where(
            ::UserDetail.arel_table[:enterprise_group_id].eq(arel_table[:source_id]).and(
              ::UserDetail.arel_table[:user_id].eq(arel_table[:user_id]))
          )

        if value
          where_exists(subquery)
        else
          where_not_exists(subquery)
        end.allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/419933")
      end
    end

    def provisioned_by_this_group?
      user&.user_detail&.provisioned_by_group_id == source_id
    end

    def enterprise_user_of_this_group?
      user&.user_detail&.enterprise_group_id == source_id
    end

    private

    override :access_level_inclusion
    def access_level_inclusion
      levels = source.access_level_values
      return if access_level.in?(levels)

      errors.add(:access_level, "is not included in the list")

      if access_level == ::Gitlab::Access::MINIMAL_ACCESS
        errors.add(:access_level, "supported on top level groups only") if group.has_parent?
        errors.add(:access_level, "not supported by license") unless group.feature_available?(:minimal_access_role)
      end
    end

    override :post_create_hook
    def post_create_hook
      super

      execute_hooks_for(:create)
    end

    def post_destroy_hook
      super

      execute_hooks_for(:destroy)
    end

    override :seat_available
    def seat_available
      return if ignore_user_limits

      super
    end
  end
end
