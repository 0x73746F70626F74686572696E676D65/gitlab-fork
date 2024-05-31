# frozen_string_literal: true

module EE
  # Namespace EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `Namespace` model
  module Namespace
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize
    include Ci::NamespaceSettings

    NAMESPACE_PLANS_TO_LICENSE_PLANS = {
      ::Plan::BRONZE => License::STARTER_PLAN,
      [::Plan::SILVER, ::Plan::PREMIUM, ::Plan::PREMIUM_TRIAL] => License::PREMIUM_PLAN,
      [
        ::Plan::GOLD,
        ::Plan::ULTIMATE,
        ::Plan::ULTIMATE_TRIAL,
        ::Plan::ULTIMATE_TRIAL_PAID_CUSTOMER,
        ::Plan::OPEN_SOURCE
      ] => License::ULTIMATE_PLAN
    }.freeze

    LICENSE_PLANS_TO_NAMESPACE_PLANS = NAMESPACE_PLANS_TO_LICENSE_PLANS.invert.freeze

    prepended do
      include EachBatch
      include Elastic::NamespaceUpdate

      has_one :elasticsearch_indexed_namespace
      has_one :gitlab_subscription
      has_one :namespace_limit, inverse_of: :namespace
      has_one :storage_limit_exclusion, class_name: 'Namespaces::Storage::LimitExclusion'
      has_one :security_orchestration_policy_configuration,
        class_name: 'Security::OrchestrationPolicyConfiguration',
        foreign_key: :namespace_id,
        inverse_of: :namespace
      has_one :upcoming_reconciliation, inverse_of: :namespace, class_name: "GitlabSubscriptions::UpcomingReconciliation"
      has_one :system_access_microsoft_application, class_name: '::SystemAccess::MicrosoftApplication'

      has_many :ci_minutes_additional_packs, class_name: "Ci::Minutes::AdditionalPack"
      has_many :compliance_management_frameworks, class_name: "ComplianceManagement::Framework"
      has_many :member_roles
      has_many :subscription_add_on_purchases, class_name: 'GitlabSubscriptions::AddOnPurchase'

      accepts_nested_attributes_for :gitlab_subscription, update_only: true
      accepts_nested_attributes_for :namespace_limit

      has_many :search_index_assignments, class_name: 'Search::NamespaceIndexAssignment'

      has_many :search_indices,
        through: :search_index_assignments,
        source: 'index',
        class_name: 'Search::Index'

      has_one :audit_event_http_namespace_filter, class_name: 'AuditEvents::Streaming::HTTP::NamespaceFilter'
      has_one :audit_event_http_instance_namespace_filter, class_name: 'AuditEvents::Streaming::HTTP::Instance::NamespaceFilter'
      has_many :work_items_colors, inverse_of: :namespace, class_name: 'WorkItems::Color'
      has_many :audit_events_streaming_group_namespace_filters, class_name: 'AuditEvents::Group::NamespaceFilter'
      has_many :audit_events_streaming_instance_namespace_filters, class_name: 'AuditEvents::Instance::NamespaceFilter'

      has_one :zoekt_enabled_namespace, class_name: '::Search::Zoekt::EnabledNamespace',
        foreign_key: :root_namespace_id, inverse_of: :namespace
      has_many :remote_development_namespace_cluster_agent_mappings,
        class_name: 'RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping',
        foreign_key: 'namespace_id',
        inverse_of: :namespace

      scope :include_gitlab_subscription, -> { includes(:gitlab_subscription) }
      scope :include_gitlab_subscription_with_hosted_plan, -> { includes(gitlab_subscription: :hosted_plan) }
      scope :join_gitlab_subscription, -> { joins("LEFT OUTER JOIN gitlab_subscriptions ON gitlab_subscriptions.namespace_id=namespaces.id") }

      scope :not_in_active_trial, -> do
        left_joins(gitlab_subscription: :hosted_plan)
          .where(gitlab_subscriptions: { trial: [nil, false] })
          .or(GitlabSubscription.where(trial_ends_on: ..Date.yesterday))
           .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/419988")
      end

      scope :not_in_default_plan, -> do
        left_joins(gitlab_subscription: :hosted_plan)
          .where.not(plans: { name: [nil, *::Plan.default_plans] })
          .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/419988")
      end

      scope :not_duo_pro_or_no_add_on, -> do
        # We return any namespace that does not have a duo pro add on.
        # We get all namespaces that do not have an add on from the left_joins and the
        # or nil condition preserves the unmatched data what would be removed due to the not eq
        # condition without it.
        left_joins(:subscription_add_on_purchases)
          .where(
            GitlabSubscriptions::AddOnPurchase.arel_table[:subscription_add_on_id].not_eq(
              GitlabSubscriptions::AddOn.code_suggestions.pick(:id)
            ).or(GitlabSubscriptions::AddOnPurchase.arel_table[:subscription_add_on_id].eq(nil)))
      end

      scope :eligible_for_trial, -> do
        left_joins(gitlab_subscription: :hosted_plan)
          .where(
            parent_id: nil,
            gitlab_subscriptions: { trial: [nil, false], trial_ends_on: [nil] },
            plans: { name: [nil, *::Plan::PLANS_ELIGIBLE_FOR_TRIAL] }
          ).allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/419988")
      end

      scope :with_feature_available_in_plan, ->(feature) do
        plans = GitlabSubscriptions::Features.saas_plans_with_feature(feature)
        matcher = ::Plan.by_name(plans)
          .with_subscriptions
          .where("gitlab_subscriptions.namespace_id = namespaces.id")
          .select('1')
        where("EXISTS (?)", matcher)
          .allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/419988")
      end

      scope :namespace_settings_with_ai_features_enabled, -> do
        joins("INNER JOIN \"namespace_settings\" ON \"namespace_settings\".\"namespace_id\" = \"namespaces\".traversal_ids[1]")
          .where(namespace_settings: { experiment_features_enabled: true })
      end

      scope :with_ai_supported_plan, ->(feature = :ai_features) do
        plan_names = GitlabSubscriptions::Features.saas_plans_with_feature(feature)

        joins("LEFT OUTER JOIN \"gitlab_subscriptions\" ON \"gitlab_subscriptions\".\"namespace_id\" = \"namespaces\".traversal_ids[1]")
          .joins("LEFT OUTER JOIN \"plans\" ON \"plans\".\"id\" = \"gitlab_subscriptions\".\"hosted_plan_id\"")
          .where(
            plans: { name: plan_names }
          ).allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/419988")
      end

      scope :with_group_wiki_repositories, -> do
        joins('INNER JOIN group_wiki_repositories ON namespaces.id = group_wiki_repositories.group_id')
      end

      delegate :eligible_additional_purchased_storage_size, :additional_purchased_storage_size=,
        :additional_purchased_storage_ends_on, :additional_purchased_storage_ends_on=,
        to: :namespace_limit, allow_nil: true
      delegate :enforce_ssh_certificates=, to: :namespace_settings
      delegate :duo_features_enabled, :lock_duo_features_enabled, to: :namespace_settings, allow_nil: true

      # `eligible_additional_purchased_storage_size` uses a FF to start checking `additional_purchased_storage_ends_on`
      # if the FF is enabled before returning `additional_purchased_storage_size`
      # To minimize the footprint of the change, aliasing namespace.additional_purchased_storage_size
      # to namespace.eligible_additional_purchased_storage_size
      alias_method :additional_purchased_storage_size, :eligible_additional_purchased_storage_size

      delegate :email, to: :owner, allow_nil: true, prefix: true

      # Opportunistically clear the +file_template_project_id+ if invalid
      before_validation :clear_file_template_project_id

      validate :validate_shared_runner_minutes_support

      validates :max_pages_size, numericality: {
        only_integer: true, greater_than_or_equal_to: 0, allow_nil: true,
        less_than: ::Gitlab::Pages::MAX_SIZE / 1.megabyte
      }

      delegate :trial_ends_on, :trial_starts_on, to: :gitlab_subscription, allow_nil: true

      delegate(
        :experiment_features_enabled,
        :experiment_features_enabled=,
        :product_analytics_enabled,
        :product_analytics_enabled=,
        :early_access_program_participant,
        to: :namespace_settings,
        allow_nil: true
      )

      delegate :security_policy_management_project, to: :security_orchestration_policy_configuration, allow_nil: true

      before_create :sync_membership_lock_with_parent

      # Changing the plan or other details may invalidate this cache
      before_save :clear_feature_available_cache

      attr_accessor :skip_sync_with_customers_dot

      before_update :mark_skip_sync_with_customers_dot, if: -> { name_changed? && !project_namespace? }
      after_commit :sync_name_with_customers_dot, on: :update, if: -> { name_previously_changed? && !project_namespace? }

      def trial?
        !!gitlab_subscription&.trial?
      end

      def upgradable?
        !!gitlab_subscription&.upgradable?
      end

      def trial_extended_or_reactivated?
        !!gitlab_subscription&.trial_extended_or_reactivated?
      end
    end

    # Only groups can be marked for deletion
    def marked_for_deletion?
      false
    end

    def namespace_limit
      limit = has_parent? ? root_ancestor.namespace_limit : super

      limit.presence || build_namespace_limit
    end

    def old_path_with_namespace_for(project)
      project.full_path.sub(/\A#{Regexp.escape(full_path)}/, full_path_before_last_save)
    end

    # Checks features (i.e. https://about.gitlab.com/pricing/) availability
    # for a given Namespace plan. This method should consider ancestor groups
    # being licensed.
    override :licensed_feature_available?
    def licensed_feature_available?(feature)
      if GitlabSubscriptions::Features.global?(feature)
        raise ArgumentError, "Use `License.feature_available?` for features that cannot be restricted to only a " \
                             "subset of projects or namespaces"
      end

      available_features = strong_memoize(:licensed_feature_available) do
        Hash.new do |h, f|
          h[f] = load_feature_available(f)
        end
      end

      available_features[feature]
    end

    def feature_available_in_plan?(feature)
      available_features = strong_memoize(:features_available_in_plan) do
        Hash.new do |h, f|
          h[f] = (plans.map(&:name) & GitlabSubscriptions::Features.saas_plans_with_feature(f)).any?
        end
      end

      available_features[feature]
    end

    def feature_available_non_trial?(feature)
      feature_available?(feature.to_sym) && !root_ancestor.trial_active?
    end

    override :actual_plan
    def actual_plan
      ::Gitlab::SafeRequestStore.fetch(actual_plan_store_key) do
        next ::Plan.default unless ::Gitlab.com?

        if parent_id
          root_ancestor.actual_plan
        else
          subscription = gitlab_subscription || generate_subscription
          hosted_plan_for(subscription) || ::Plan.free
        end
      end
    end

    def has_subscription?
      !root_ancestor.gitlab_subscription.nil?
    end

    def actual_plan_store_key
      "namespaces:#{id}:actual_plan"
    end

    def plan_name_for_upgrading
      return ::Plan::FREE if trial_active?

      actual_plan_name
    end

    def over_storage_limit?
      ::Namespaces::Storage::RootSize.new(root_ancestor).above_size_limit?
    end

    def read_only?
      over_storage_limit? ||
        ::Namespaces::FreeUserCap::Enforcement.new(root_ancestor).over_limit? ||
        (block_seat_overages? && seat_overage?)
    end

    def total_repository_size_excess
      strong_memoize(:total_repository_size_excess) do
        total_excess = (total_repository_size_arel - repository_size_limit_arel).sum

        projects_for_repository_size_excess.pick(total_excess) || 0
      end
    end

    def repository_size_excess_project_count
      strong_memoize(:repository_size_excess_project_count) do
        projects_for_repository_size_excess.count
      end
    end

    def total_repository_size
      strong_memoize(:total_repository_size) do
        all_projects
          .joins(:statistics)
          .pick(total_repository_size_arel.sum) || 0
      end
    end

    def contains_locked_projects?
      total_repository_size_excess > additional_purchased_storage_size.megabytes
    end

    def actual_repository_size_limit
      repository_size_limit || ::Gitlab::CurrentSettings.repository_size_limit
    end

    ##
    # Returns the actual storage size limit for the namespace
    # If the namespace is in Project enforcement, we return the repository_size_limit setting
    # And if the namespace is in Namespace enforcement we return
    # whatever enforceable storage is configured for the namespace
    #
    # This only return the storage limit included in the plan, to add the purchased storage to the
    # limit please use root_storage_size.limit
    def actual_size_limit
      return actual_repository_size_limit unless ::Namespaces::Storage::Enforcement.enforce_limit?(root_ancestor)

      # Both limits are returned in bytes, but the Namespace enforcement limits are stored in megabytes,
      # so we need to call `megabytes` here
      ::Namespaces::Storage::Enforcement.enforceable_storage_limit(root_ancestor).megabytes
    end

    def sync_membership_lock_with_parent
      if parent&.membership_lock?
        self.membership_lock = true
      end
    end

    def ci_minutes_usage
      strong_memoize(:ci_minutes_usage) do
        ::Ci::Minutes::Usage.new(self)
      end
    end

    # The same method name is used also at project level
    def shared_runners_minutes_limit_enabled?
      any_project_with_shared_runners_enabled? && ci_minutes_usage.quota_enabled?
    end

    def any_project_with_shared_runners_enabled?
      Rails.cache.fetch([self, :has_project_with_shared_runners_enabled], expires_in: 5.minutes) do
        any_project_with_shared_runners_enabled_with_cte?
      end
    end

    # These helper methods are required to not break the Namespace API.
    def memoized_plans=(plans)
      @plans = plans # rubocop: disable Gitlab/ModuleWithInstanceVariables
    end

    def plans
      @plans ||=
        if parent_id
          ::Plan.hosted_plans_for_namespaces(self_and_ancestors.select(:id))
        else
          ::Plan.hosted_plans_for_namespaces(self)
        end
    end

    # When a purchasing a GL.com plan for a User namespace
    # we only charge for a single user.
    # This method is overwritten in Group where we made the calculation
    # for Group namespaces.
    def billable_members_count(_requested_hosted_plan = nil)
      1
    end

    # When a purchasing a GL.com plan for a User namespace
    # we only charge for a single user.
    # This method is overwritten in Group where we made the calculation
    # for Group namespaces.
    def billed_user_ids(_requested_hosted_plan = nil)
      {
        user_ids: [owner_id],
        group_member_user_ids: [],
        project_member_user_ids: [],
        shared_group_user_ids: [],
        shared_project_user_ids: []
      }
    end

    def eligible_for_trial?
      ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
        !has_parent? &&
        never_had_trial? &&
        plan_eligible_for_trial?
    end

    # Be sure to call this on root_ancestor since plans are only associated
    # with the top-level namespace, not with subgroups.
    def trial_active?
      trial? && trial_ends_on.present? && trial_ends_on >= Date.today
    end

    def never_had_trial?
      trial_ends_on.nil?
    end

    def trial_expired?
      trial_ends_on.present? && trial_ends_on < Date.today
    end

    # A namespace may not have a file template project
    def checked_file_template_project
      nil
    end

    def checked_file_template_project_id
      checked_file_template_project&.id
    end

    def store_security_reports_available?
      feature_available?(:sast) ||
        feature_available?(:secret_detection) ||
        feature_available?(:dependency_scanning) ||
        feature_available?(:container_scanning) ||
        feature_available?(:cluster_image_scanning) ||
        feature_available?(:dast) ||
        feature_available?(:coverage_fuzzing) ||
        feature_available?(:api_fuzzing)
    end

    def ingest_sbom_reports_available?
      licensed_feature_available?(:dependency_scanning) ||
        licensed_feature_available?(:container_scanning) ||
        licensed_feature_available?(:license_scanning)
    end

    def default_plan?
      actual_plan_name == ::Plan::DEFAULT
    end

    def free_plan?
      actual_plan_name == ::Plan::FREE
    end

    def bronze_plan?
      actual_plan_name == ::Plan::BRONZE
    end

    def silver_plan?
      actual_plan_name == ::Plan::SILVER
    end

    def premium_plan?
      actual_plan_name == ::Plan::PREMIUM
    end

    def premium_trial_plan?
      actual_plan_name == ::Plan::PREMIUM_TRIAL
    end

    def gold_plan?
      actual_plan_name == ::Plan::GOLD
    end

    def ultimate_plan?
      actual_plan_name == ::Plan::ULTIMATE
    end

    def ultimate_trial_plan?
      actual_plan_name == ::Plan::ULTIMATE_TRIAL
    end

    def ultimate_trial_paid_customer_plan?
      actual_plan_name == ::Plan::ULTIMATE_TRIAL_PAID_CUSTOMER
    end

    def opensource_plan?
      actual_plan_name == ::Plan::OPEN_SOURCE
    end

    def plan_eligible_for_trial?
      ::Plan::PLANS_ELIGIBLE_FOR_TRIAL.include?(actual_plan_name)
    end

    def free_personal?
      user_namespace? && !paid?
    end

    override :prevent_delete?
    def prevent_delete?
      super && !trial?
    end

    def use_elasticsearch?
      ::Gitlab::CurrentSettings.elasticsearch_indexes_namespace?(self)
    end

    def use_zoekt?
      ::Search::Zoekt.index?(self)
    end

    def search_code_with_zoekt?
      ::Search::Zoekt.search?(self)
    end

    def has_index_assignment?(type:)
      ::Search::NamespaceIndexAssignment.has_assignment?(namespace: self, type: type)
    end

    def invalidate_elasticsearch_indexes_cache!
      ::Gitlab::CurrentSettings.invalidate_elasticsearch_indexes_cache_for_namespace!(self.id)
    end

    def elastic_namespace_ancestry
      separator = '-'
      self_and_ancestor_ids(hierarchy_order: :desc).join(separator) + separator
    end

    def hashed_root_namespace_id
      ::Search.hash_namespace_id(root_ancestor.id)
    end

    def root_storage_size
      if ::Namespaces::Storage::Enforcement.enforce_limit?(root_ancestor)
        ::Namespaces::Storage::RootSize.new(root_ancestor)
      else
        ::Namespaces::Storage::RootExcessSize.new(root_ancestor)
      end
    end

    def user_cap_available?
      return false unless group_namespace?
      return false unless ::Gitlab.com?
      return false if ramon?

      true
    end

    def ramon?
      ::Feature.enabled?(:ramon, self, type: :wip)
    end

    def block_seat_overages?
      false
    end

    def capacity_left_for_user?(_user)
      true
    end

    def exclude_guests?
      false
    end

    def delete_redundant_policy_projects?
      ::Feature.enabled?(:security_policies_unassign_redundant_policy_projects, self)
    end
    strong_memoize_attr :delete_redundant_policy_projects?

    def all_security_orchestration_policy_configurations(include_invalid: false)
      return Array.wrap(security_orchestration_policy_configuration) if self_and_ancestor_ids.blank?

      security_orchestration_policies_for_namespaces(self_and_ancestor_ids, include_invalid: include_invalid)
    end

    def all_descendant_security_orchestration_policy_configurations
      return [] if self_and_descendant_ids.blank?

      security_orchestration_policies_for_namespaces(self_and_descendant_ids)
    end

    def all_inherited_security_orchestration_policy_configurations(include_invalid: false)
      return [] if ancestor_ids.blank?

      security_orchestration_policies_for_namespaces(ancestor_ids, include_invalid: include_invalid)
    end

    def all_projects_pages_domains(only_verified: false)
      domains = ::PagesDomain.where(project_id: all_projects)
      domains = domains.verified if only_verified

      domains
    end

    def domain_verification_available?
      ::Gitlab.com? && root? && licensed_feature_available?(:domain_verification)
    end

    def enforce_ssh_certificates?
      root? && namespace_settings.enforce_ssh_certificates?
    end

    def ssh_certificates_available?
      root? && licensed_feature_available?(:ssh_certificates)
    end

    def custom_roles_enabled?
      root_ancestor.licensed_feature_available?(:custom_roles)
    end

    def okrs_mvc_feature_flag_enabled?
      ::Feature.enabled?(:okrs_mvc, self)
    end

    def reached_project_access_token_limit?
      false
    end

    def resource_parent
      self
    end

    private

    def security_orchestration_policies_for_namespaces(namespace_ids, include_invalid: false)
      configurations = ::Security::OrchestrationPolicyConfiguration
        .for_namespace(namespace_ids)
        .with_project_and_namespace

      return configurations if include_invalid

      configurations.select { |configuration| configuration&.policy_configuration_valid? }
    end

    def any_project_with_shared_runners_enabled_with_cte?
      projects_query = if user_namespace?
                         projects
                       else
                         cte = ::Gitlab::SQL::CTE.new(:namespace_self_and_descendants_cte, self_and_descendant_ids)

                         ::Project
                           .with(cte.to_arel)
                           .from([::Project.table_name, cte.table.name].join(', '))
                           .where(::Project.arel_table[:namespace_id].eq(cte.table[:id]))
                       end

      projects_query.with_shared_runners_enabled.any?
    end

    def validate_shared_runner_minutes_support
      return if root?

      if shared_runners_minutes_limit_changed?
        errors.add(:shared_runners_minutes_limit, 'is not supported for this namespace')
      end
    end

    def clear_feature_available_cache
      clear_memoization(:licensed_feature_available)
    end

    def mark_skip_sync_with_customers_dot
      self.skip_sync_with_customers_dot = update_within_same_minute?
    end

    def sync_name_with_customers_dot
      return if skip_sync_with_customers_dot
      return unless ::Gitlab.com?
      return if user_namespace? && owner.privatized_by_abuse_automation?
      return unless root? && (trial? || actual_plan&.paid?)
      return if update_to_customerdot_blocked?

      ::Namespaces::SyncNamespaceNameWorker.perform_async(id)
    end

    def load_feature_available(feature)
      globally_available = License.feature_available?(feature)

      if ::Gitlab::CurrentSettings.should_check_namespace_plan?
        globally_available && feature_available_in_plan?(feature)
      else
        globally_available
      end
    end

    def clear_file_template_project_id
      return unless has_attribute?(:file_template_project_id)
      return if checked_file_template_project_id.present?

      self.file_template_project_id = nil
    end

    def generate_subscription
      return unless persisted?
      return if ::Gitlab::Database.read_only?

      create_gitlab_subscription(
        plan_code: Plan::FREE,
        trial: trial_active?,
        start_date: created_at,
        seats: 0
      )
    end

    def total_repository_size_arel
      arel_table = ::ProjectStatistics.arel_table
      arel_table[:repository_size] + arel_table[:lfs_objects_size]
    end

    def projects_for_repository_size_excess
      projects_with_limits = ::Project.without_unlimited_repository_size_limit

      if actual_repository_size_limit.to_i > 0
        # When the instance or namespace level limit is set, we need to include those without project level limits
        projects_with_limits = projects_with_limits.or(::Project.without_repository_size_limit)
      end

      all_projects
        .merge(projects_with_limits)
        .with_total_repository_size_greater_than(repository_size_limit_arel)
    end

    def repository_size_limit_arel
      instance_size_limit = actual_repository_size_limit.to_i

      if instance_size_limit > 0
        self.class.arel_table.coalesce(
          ::Project.arel_table[:repository_size_limit],
          instance_size_limit
        )
      else
        ::Project.arel_table[:repository_size_limit]
      end
    end

    def hosted_plan_for(subscription)
      return unless subscription

      subscription.hosted_plan
    end

    def update_within_same_minute?
      time_format = '%d/%m/%Y %H:%M'
      minute_time_was = updated_at_was.strftime(time_format)
      minute_time_is = updated_at.strftime(time_format)

      minute_time_was == minute_time_is
    end

    def update_to_customerdot_blocked?
      ::Gitlab::ApplicationRateLimiter.peek(:update_namespace_name, scope: self)
    end
  end
end
