# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnPurchase < ApplicationRecord
    include EachBatch
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    CLEANUP_DELAY_PERIOD = 14.days

    belongs_to :add_on, foreign_key: :subscription_add_on_id, inverse_of: :add_on_purchases
    belongs_to :namespace, optional: true
    belongs_to :organization, class_name: 'Organizations::Organization'
    has_many :assigned_users, class_name: 'GitlabSubscriptions::UserAddOnAssignment', inverse_of: :add_on_purchase

    validates :add_on, :expires_on, presence: true
    validate :valid_namespace, if: :gitlab_com?
    validates :subscription_add_on_id, uniqueness: { scope: :namespace_id }
    validates :quantity,
      presence: true,
      numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :purchase_xid,
      presence: true,
      length: { maximum: 255 }

    scope :active, -> { where('expires_on >= ?', Date.current) }
    scope :ready_for_cleanup, -> { where('expires_on < ?', CLEANUP_DELAY_PERIOD.ago.to_date) }
    scope :trial, -> { where(trial: true) }
    scope :by_add_on_name, ->(name) { joins(:add_on).where(add_on: { name: name }) }
    scope :by_namespace_id, ->(namespace_id) { where(namespace_id: namespace_id) }
    scope :for_gitlab_duo_pro, -> { where(subscription_add_on_id: AddOn.code_suggestions.pick(:id)) }
    scope :for_product_analytics, -> { where(subscription_add_on_id: AddOn.product_analytics.pick(:id)) }
    scope :for_duo_enterprise, -> { where(subscription_add_on_id: AddOn.duo_enterprise.pick(:id)) }
    scope :for_user, ->(user) { where(namespace_id: user.billable_gitlab_duo_pro_root_group_ids) }
    scope :assigned_to_user, ->(user) do
      active.joins(:assigned_users).merge(UserAddOnAssignment.by_user(user))
    end

    scope :requiring_assigned_users_refresh, ->(limit) do
      # Fetches add_on_purchases whose assigned_users have not been refreshed in last 8 hours.
      # Used primarily by BulkRefreshUserAssignmentsWorker, which is scheduled every 4 hours
      # by ScheduleBulkRefreshUserAssignmentsWorker.
      for_gitlab_duo_pro
        .where("last_assigned_users_refreshed_at < ? OR last_assigned_users_refreshed_at is NULL", 8.hours.ago)
        .limit(limit)
    end

    def self.next_candidate_requiring_assigned_users_refresh
      requiring_assigned_users_refresh(1)
        .order('last_assigned_users_refreshed_at ASC NULLS FIRST')
        .lock('FOR UPDATE SKIP LOCKED')
        .includes(:namespace)
        .first
    end

    def self.uniq_add_on_names
      joins(:add_on).pluck(:name).uniq
    end

    def already_assigned?(user)
      assigned_users.where(user: user).exists?
    end

    def active?
      expires_on >= Date.current
    end

    def expired?
      !active?
    end

    def delete_ineligible_user_assignments_in_batches!(batch_size: 50)
      deleted_assignments_count = 0

      assigned_users.each_batch(of: batch_size) do |batch|
        ineligible_user_ids = filter_ineligible_assigned_user_ids(batch.pluck_user_ids.to_set)

        deleted_assignments_count += batch.for_user_ids(ineligible_user_ids).delete_all

        cache_keys = ineligible_user_ids.map do |user_id|
          format(User::DUO_PRO_ADD_ON_CACHE_KEY, user_id: user_id)
        end

        Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end

      deleted_assignments_count
    end

    private

    def filter_ineligible_assigned_user_ids(assigned_user_ids)
      return assigned_user_ids - saas_eligible_user_ids if namespace

      assigned_user_ids - self_managed_eligible_users_relation.where(id: assigned_user_ids).pluck(:id)
    end

    def saas_eligible_user_ids
      @eligible_user_ids ||= namespace.gitlab_duo_pro_eligible_user_ids
    end

    def self_managed_eligible_users_relation
      @self_managed_eligible_users_relation ||= GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(
        add_on_type: add_on_type
      ).execute
    end

    def add_on_type
      add_on.name.to_sym
    end

    def gitlab_com?
      ::Gitlab::CurrentSettings.should_check_namespace_plan?
    end

    def valid_namespace
      return if namespace.present? && namespace.root? && namespace.group_namespace?

      errors.add(:namespace, :invalid)
    end
  end
end
