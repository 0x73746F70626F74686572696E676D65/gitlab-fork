# frozen_string_literal: true

module EE
  module NamespaceSetting
    extend ActiveSupport::Concern

    prepended do
      validates :unique_project_download_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
        presence: true
      validates :unique_project_download_limit_interval_in_seconds,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10.days.to_i },
        presence: true
      validates :unique_project_download_limit_allowlist,
        length: { maximum: 100, message: -> (object, data) { _("exceeds maximum length (100 usernames)") } },
        allow_nil: false,
        user_existence: true,
        if: :unique_project_download_limit_allowlist_changed?
      validates :unique_project_download_limit_alertlist,
        length: { maximum: 100, message: ->(object, data) { _("exceeds maximum length (100 user ids)") } },
        allow_nil: false,
        user_id_existence: true,
        if: :unique_project_download_limit_alertlist_changed?
      validates :experiment_features_enabled, inclusion: { in: [true, false] }

      validate :user_cap_allowed, if: -> { enabling_user_cap? }
      validate :experiment_features_allowed
      validate :product_analytics_allowed

      before_validation :disable_product_analytics, if: :should_disable_product_analytics?

      before_save :set_prevent_sharing_groups_outside_hierarchy, if: -> { user_cap_enabled? }
      after_save :disable_project_sharing!, if: -> { user_cap_enabled? }

      delegate :root_ancestor, to: :namespace

      def prevent_forking_outside_group?
        saml_setting = root_ancestor.saml_provider&.prohibited_outer_forks?

        return saml_setting unless namespace.feature_available?(:group_forking_protection)

        saml_setting || root_ancestor.namespace_settings&.prevent_forking_outside_group
      end

      # Define three instance methods:
      #
      # - [attribute]_of_parent_group         Returns the configuration value of the parent group
      # - [attribute]?(inherit_group_setting) Returns the final value after inheriting the parent group
      # - [attribute]_locked?                 Returns true if the value is inherited from the parent group
      def self.cascading_with_parent_namespace(attribute)
        define_method("#{attribute}_of_parent_group") do
          namespace&.parent&.namespace_settings&.public_send("#{attribute}?", inherit_group_setting: true)
        end

        define_method("#{attribute}?") do |inherit_group_setting: false|
          if inherit_group_setting
            result = public_send(attribute.to_s) || public_send("#{attribute}_of_parent_group") # rubocop:disable GitlabSecurity/PublicSend
          else
            result = public_send(attribute.to_s) # rubocop:disable GitlabSecurity/PublicSend
          end

          !!result
        end

        define_method("#{attribute}_locked?") do
          !!public_send("#{attribute}_of_parent_group") # rubocop:disable GitlabSecurity/PublicSend
        end
      end

      cascading_with_parent_namespace :only_allow_merge_if_pipeline_succeeds
      cascading_with_parent_namespace :allow_merge_on_skipped_pipeline
      cascading_with_parent_namespace :only_allow_merge_if_all_discussions_are_resolved
      cascading_with_parent_namespace :allow_merge_without_pipeline

      def unique_project_download_limit_alertlist
        self[:unique_project_download_limit_alertlist].presence || active_owner_ids
      end

      # TODO: remove :ai_chat condition after Chat goes GA
      # https://gitlab.com/gitlab-org/gitlab/-/issues/441099
      def experiment_settings_allowed?
        namespace.root? &&
          ::Gitlab::CurrentSettings.should_check_namespace_plan? &&
          (namespace.feature_available?(:experimental_features) || namespace.feature_available?(:ai_chat))
      end

      def product_analytics_settings_allowed?
        experiment_settings_allowed? &&
          ::Feature.enabled?(:product_analytics_beta_optin, namespace) &&
          ::Gitlab::CurrentSettings.product_analytics_enabled?
      end

      def user_cap_enabled?
        new_user_signups_cap.present? && namespace.root?
      end

      private

      def enabling_user_cap?
        return false unless persisted? && new_user_signups_cap_changed?

        new_user_signups_cap_was.nil?
      end

      def user_cap_allowed
        return if namespace.user_cap_available? && namespace.root? && !namespace.shared_externally?

        errors.add(:new_user_signups_cap, _("cannot be enabled"))
      end

      def set_prevent_sharing_groups_outside_hierarchy
        self.prevent_sharing_groups_outside_hierarchy = true
      end

      def disable_project_sharing!
        namespace.update_attribute(:share_with_group_lock, true)
      end

      def active_owner_ids
        return [] unless namespace&.group_namespace?

        owner_ids = []
        namespace.all_owner_members.non_invite.each_batch do |relation|
          owner_ids.concat(::User.active.id_in(relation.pluck_user_ids).pluck_primary_key)
        end
        owner_ids
      end

      def experiment_features_allowed
        return unless experiment_features_enabled_changed?
        return if experiment_settings_allowed?

        errors.add(:experiment_features_enabled, _("Experiment features' settings not allowed."))
      end

      def product_analytics_allowed
        return unless experiment_features_enabled_changed? || product_analytics_enabled_changed?
        return if experiment_features_enabled || !product_analytics_enabled

        errors.add(:product_analytics_enabled,
          _("Product analytics requires Experiment and Beta features to be enabled."))
      end

      def should_disable_product_analytics?
        # Product analytics can only be enabled if experiment features are enabled as well.
        # The checkbox to enable/disable product analytics is behind feature flag.
        # If the feature flag was enabled for a namespace but for some reason we disable the feature flag later
        # they will not be able to unselect product analytics checkbox as it would be hidden from them.
        # This may prevent them updating experiment features group setting from true to false,
        # because the product_analytics_allowed validation will fail.
        # For this specific scenario we disable product analytics when disabling experiment features.
        return false if ::Feature.enabled?(:product_analytics_beta_optin, namespace)

        experiment_features_enabled_was && !experiment_features_enabled
      end

      def disable_product_analytics
        self.product_analytics_enabled = false
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      EE_NAMESPACE_SETTINGS_PARAMS = %i[
        unique_project_download_limit
        unique_project_download_limit_interval_in_seconds
        unique_project_download_limit_allowlist
        unique_project_download_limit_alertlist
        auto_ban_user_on_excessive_projects_download
        default_compliance_framework_id
        only_allow_merge_if_pipeline_succeeds
        allow_merge_without_pipeline
        allow_merge_on_skipped_pipeline
        only_allow_merge_if_all_discussions_are_resolved
        experiment_features_enabled
        service_access_tokens_expiration_enforced
      ].freeze

      override :allowed_namespace_settings_params
      def allowed_namespace_settings_params
        super + EE_NAMESPACE_SETTINGS_PARAMS
      end
    end
  end
end
