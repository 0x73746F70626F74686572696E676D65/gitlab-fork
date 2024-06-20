# frozen_string_literal: true

module EE
  module Member
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include SafeFormatHelper

    prepended do
      include Elastic::ApplicationVersionedSearch
      include MemberRoles::MemberRoleRelation
      include ::GitlabSubscriptions::SubscriptionHelper
      include ::GitlabSubscriptions::BillableUsersUtils

      base_access_level_attr :access_level

      state_machine :state, initial: :active do
        event :wait do
          transition active: :awaiting, unless: :last_owner?
        end

        event :activate do
          transition awaiting: :active, if: :has_capacity_left?
        end

        state :awaiting, value: ::Member::STATE_AWAITING
        state :active, value: ::Member::STATE_ACTIVE
      end

      validate :seat_available, on: :create

      scope :awaiting, -> { where(state: ::Member::STATE_AWAITING) }
      scope :non_awaiting, -> { where.not(state: ::Member::STATE_AWAITING) }

      scope :banned_from, ->(namespace) do
        sql = "INNER JOIN namespace_bans
               ON namespace_bans.user_id = members.user_id
               AND namespace_bans.namespace_id = ?"
        joins(sanitize_sql_array([sql, namespace.id]))
      end

      scope :not_banned_in, ->(namespace) do
        where.not(user_id: ::Namespaces::NamespaceBan.where(namespace: namespace).select(:user_id))
      end

      scope :with_custom_role, -> { where.not(member_role_id: nil) }

      scope :elevated_guests, -> do
        where(access_level: ::Gitlab::Access::GUEST).joins(:member_role).merge(MemberRole.occupies_seat)
      end

      scope :with_elevated_guests, -> do
        non_guests.or(
          where(access_level: ::Gitlab::Access::GUEST)
          .merge(MemberRole.occupies_seat)
        ).left_outer_joins(:member_role)
      end

      before_create :set_membership_activation

      scope :with_csv_entity_associations, -> do
        includes(:user, source: [:route, :parent])
      end

      scope :distinct_awaiting_or_invited_for_group, ->(group) do
        awaiting
        .or(::Member.invite)
        .in_hierarchy(group)
        .select('DISTINCT ON (members.user_id, members.invite_email) members.*')
        .includes(:user)
        .order(:user_id, :invite_email)
      end
    end

    override :notification_service
    def notification_service
      if ldap
        # LDAP users shouldn't receive notifications about membership changes
        ::EE::NullNotificationService.new
      else
        super
      end
    end

    override :maintaining_elasticsearch?
    def maintaining_elasticsearch?
      ::Gitlab::CurrentSettings.elasticsearch_indexing?
    end

    override :maintain_elasticsearch_create
    def maintain_elasticsearch_create
      return unless user

      ::Elastic::ProcessBookkeepingService.track!(user)
    end

    override :maintain_elasticsearch_update
    def maintain_elasticsearch_update(updated_attributes: previous_changes.keys); end

    override :maintain_elasticsearch_destroy
    def maintain_elasticsearch_destroy
      return unless user

      ::Elastic::ProcessBookkeepingService.track!(user)
    end

    def queue_for_approval(new_access_level, requested_by, member_role_id = nil)
      member_approvals.find_or_create_by(
        member_namespace: member_namespace,
        new_access_level: new_access_level,
        member_role_id: member_role_id,
        status: ::Members::MemberApproval.statuses[:pending]
      ) do |new_approval|
        new_approval.old_access_level = access_level
        new_approval.requested_by = requested_by
        new_approval.user_id = user_id
      end
    rescue ActiveRecord::RecordNotUnique
      member_approvals.find_by(
        member_namespace: member_namespace,
        new_access_level: new_access_level,
        member_role_id: member_role_id,
        status: ::Members::MemberApproval.statuses[:pending]
      )
    end

    def sso_enforcement
      unless ::Gitlab::Auth::GroupSaml::MembershipEnforcer.new(group).can_add_user?(user)
        troubleshoot_link_url = ::Gitlab::Routing.url_helpers.help_page_path('user/group/saml_sso/troubleshooting_scim')
        troubleshoot_link = ActionController::Base.helpers.link_to('', troubleshoot_link_url, target: '_blank',
          rel: 'noopener noreferrer')
        msg = safe_format(
          s_(
            "is not linked to a SAML account or has an inactive SCIM identity. " \
            "For information on how to resolve this error, see the " \
            "%{troubleshoot_link_start}troubleshooting SCIM documentation%{troubleshoot_link_end}."
          ),
          tag_pair(troubleshoot_link, :troubleshoot_link_start, :troubleshoot_link_end)
        )

        errors.add(:user, msg)
      end
    end

    # The method is exposed in the API as is_using_seat
    # in ee/lib/ee/api/entities.rb
    #
    # rubocop: disable Naming/PredicateName
    def is_using_seat
      return user.using_gitlab_com_seat?(source) if ::Gitlab.com?

      user&.using_license_seat?
    end
    # rubocop: enable Naming/PredicateName

    def source_kind
      source.is_a?(Group) && source.parent.present? ? 'Sub group' : source.class.to_s
    end

    def group_has_domain_limitations?
      return false unless group

      group.licensed_feature_available?(:group_allowed_email_domains) && group_allowed_email_domains.any?
    end

    def group_domain_limitations
      return unless group

      if user
        return if user.project_bot? || user.security_policy_bot? || user.service_account?

        validate_users_email
        validate_email_verified
      else
        validate_invitation_email
      end
    end

    def group_saml_identity(root_ancestor: false)
      saml_group = root_ancestor ? group.root_ancestor : group

      return unless saml_group.saml_provider

      if user.group_saml_identities.loaded?
        user.group_saml_identities.detect { |i| i.saml_provider_id == saml_group.saml_provider.id }
      else
        user.group_saml_identities.find_by(saml_provider: saml_group.saml_provider)
      end
    end

    def prevent_role_assignement?(_current_user, _params)
      false
    end

    private

    def group_allowed_email_domains
      return [] unless group

      group.root_ancestor_allowed_email_domains
    end

    def validate_users_email
      return if matches_at_least_one_group_allowed_email_domain?(user.email)

      errors.add(:user, email_does_not_match_any_allowed_domains(user.email))
    end

    def validate_invitation_email
      return if matches_at_least_one_group_allowed_email_domain?(invite_email)

      errors.add(:invite_email, email_does_not_match_any_allowed_domains(invite_email))
    end

    def validate_email_verified
      return if user.primary_email_verified?

      return if group_saml_identity(root_ancestor: true).present?
      return if group.root_ancestor.scim_identities.for_user(user).exists?

      errors.add(:user, _('is not verified.'))
    end

    def email_does_not_match_any_allowed_domains(email)
      msg_1 = signup_email_invalid_message

      msg_2 = error_message[created_by_key][:group_setting]

      [msg_1, msg_2].join(' ')
    end

    def matches_at_least_one_group_allowed_email_domain?(email)
      group_allowed_email_domains.any? do |allowed_email_domain|
        allowed_email_domain.email_matches_domain?(email)
      end
    end

    def set_membership_activation
      self.state = ::Member::STATE_AWAITING unless has_capacity_left?
    end

    def last_owner?
      source.root_ancestor.last_owner?(self.user)
    end

    def has_capacity_left?
      source.root_ancestor.capacity_left_for_user?(user)
    end

    def seat_available
      return unless source # due to source being evaluated during creation, source must be present to evaluate
      return if ::Namespaces::FreeUserCap::Enforcement.new(source.root_ancestor).seat_available?(user)

      msg = format(
        _("cannot be added since you've reached your %{free_limit} member limit for %{namespace_name}"),
        free_limit: ::Namespaces::FreeUserCap.dashboard_limit, namespace_name: source.root_ancestor.name
      )
      errors.add(:base, msg) # add to base here since :user is getting `The member's email address` appended
    end

    def validate_member_role_belongs_to_same_root_namespace
      return unless member_role_id && member_namespace.custom_roles_enabled?
      return unless member_role.namespace_id

      return if member_namespace.id == member_role.namespace_id
      return if member_namespace.root_ancestor.id == member_role.namespace_id

      errors.add(:member_namespace, _("must be in same hierarchy as custom role's namespace"))
    end

    override :post_update_hook
    def post_update_hook
      super

      execute_hooks_for(:update) if saved_change_to_access_level? || saved_change_to_expires_at?
    end

    override :post_create_hook
    def post_create_hook
      super

      execute_hooks_for(:create)
    end

    def execute_hooks_for(event)
      return unless source.is_a?(Group)
      return unless source.licensed_feature_available?(:group_webhooks)
      return unless GroupHook.where(group_id: source.self_and_ancestors).exists?

      run_after_commit do
        data = ::Gitlab::HookData::GroupMemberBuilder.new(self).build(event)
        source.execute_hooks(data, :member_hooks)
      end
    end
  end
end
