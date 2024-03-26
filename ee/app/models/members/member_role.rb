# frozen_string_literal: true

class MemberRole < ApplicationRecord # rubocop:disable Gitlab/NamespacedClass
  include GitlabSubscriptions::SubscriptionHelper

  MAX_COUNT_PER_GROUP_HIERARCHY = 10

  NON_PERMISSION_COLUMNS = [
    :base_access_level,
    :created_at,
    :description,
    :id,
    :name,
    :namespace_id,
    :updated_at,
    :occupies_seat
  ].freeze
  LEVELS = ::Gitlab::Access.options_with_owner.values.freeze

  has_many :members
  has_many :saml_providers
  has_many :saml_group_links
  belongs_to :namespace

  validates :namespace, presence: true, if: :gitlab_com_subscription?
  validates :name, presence: true
  validates :name, uniqueness: { scope: :namespace_id }, on: :create
  validates :base_access_level, presence: true, inclusion: { in: LEVELS }
  validate :belongs_to_top_level_namespace
  validate :max_count_per_group_hierarchy, on: :create
  validate :validate_namespace_locked, on: :update
  validate :base_access_level_locked, on: :update
  validate :validate_requirements
  validate :ensure_at_least_one_permission_is_enabled

  validates_associated :members

  before_save :set_occupies_seat

  scope :elevating, -> do
    return none if elevating_permissions.empty?

    query = elevating_permissions.map { |permission| "#{permission} = true" }
                                 .join(" OR ")
    where(query)
  end

  scope :by_namespace, ->(group_ids) { where(namespace_id: group_ids) }
  scope :for_instance, -> { where(namespace_id: nil) }

  scope :with_members_count, -> do
    left_outer_joins(:members)
      .group(:id)
      .select(MemberRole.default_select_columns)
      .select('COUNT(members.id) AS members_count')
  end

  before_destroy :prevent_delete_after_member_associated

  def self.levels_sentence
    ::Gitlab::Access
      .options_with_owner
      .map { |name, value| "#{value} (#{name})" }
      .to_sentence
  end

  def self.declarative_policy_class
    'Members::MemberRolePolicy'
  end

  class << self
    def elevating_permissions
      MemberRole.all_customizable_permissions.reject { |_k, v| v[:skip_seat_consumption] }.keys
    end

    def all_customizable_permissions
      Gitlab::CustomRoles::Definition.all
    end

    def all_customizable_project_permissions
      MemberRole.all_customizable_permissions.select { |_k, v| v[:project_ability] }.keys
    end

    def all_customizable_group_permissions
      MemberRole.all_customizable_permissions.select { |_k, v| v[:group_ability] }.keys
    end

    def customizable_permissions_exempt_from_consuming_seat
      MemberRole.all_customizable_permissions.select { |_k, v| v[:skip_seat_consumption] }.keys
    end

    def permission_enabled?(permission)
      return true unless ::Feature::Definition.get("custom_ability_#{permission}")

      ::Feature.enabled?("custom_ability_#{permission}")
    end
  end

  def enabled_permissions
    MemberRole.all_customizable_permissions.keys.filter do |permission|
      attributes[permission.to_s] && self.class.permission_enabled?(permission)
    end
  end

  private

  def belongs_to_top_level_namespace
    return if !namespace || namespace.root?

    errors.add(:namespace, s_("MemberRole|must be top-level namespace"))
  end

  def max_count_per_group_hierarchy
    return unless namespace
    return if namespace.member_roles.count < MAX_COUNT_PER_GROUP_HIERARCHY

    errors.add(
      :namespace,
      s_(
        "MemberRole|maximum number of Member Roles are already in use by the group hierarchy. " \
        "Please delete an existing Member Role."
      )
    )
  end

  def validate_namespace_locked
    return unless namespace_id_changed?

    errors.add(:namespace, s_("MemberRole|can't be changed"))
  end

  def validate_requirements
    self.class.all_customizable_permissions.each do |permission, params|
      requirements = params[:requirements]

      next unless self[permission] # skipping permissions not set for the object
      next unless requirements.present? # skipping permissions that have no requirements

      requirements.each do |requirement|
        next if self[requirement] # the requirement is met

        errors.add(:base,
          format(s_("MemberRole|%{requirement} has to be enabled in order to enable %{permission}"),
            requirement: requirement.to_s.humanize, permission: permission.to_s.humanize)
        )
      end
    end
  end

  def ensure_at_least_one_permission_is_enabled
    return if self.class.all_customizable_permissions.keys.any? { |attr| self[attr] }

    errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
  end

  def base_access_level_locked
    return unless changed_attributes.include?('base_access_level')

    errors.add(
      :base_access_level,
      s_('MemberRole|cannot be changed. Please create a new Member Role instead.')
    )
  end

  def prevent_delete_after_member_associated
    return unless members.present?

    errors.add(
      :base,
      s_(
        "MemberRole|Role is assigned to one or more group members. " \
        "Remove role from all group members, then delete role."
      )
    )

    throw :abort # rubocop:disable Cop/BanCatchThrow
  end

  def set_occupies_seat
    self.occupies_seat = base_access_level > Gitlab::Access::GUEST ||
      self.class.elevating_permissions.any? { |attr| self[attr] }
  end
end
