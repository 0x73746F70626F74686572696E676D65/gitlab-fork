# frozen_string_literal: true

module EE
  module Plan
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      FREE = 'free'
      BRONZE = 'bronze'
      SILVER = 'silver'
      PREMIUM = 'premium'
      GOLD = 'gold'
      ULTIMATE = 'ultimate'
      ULTIMATE_TRIAL = 'ultimate_trial'
      ULTIMATE_TRIAL_PAID_CUSTOMER = 'ultimate_trial_paid_customer'
      PREMIUM_TRIAL = 'premium_trial'
      OPEN_SOURCE = 'opensource'

      EE_DEFAULT_PLANS = (const_get(:DEFAULT_PLANS, false) + [FREE]).freeze
      PAID_HOSTED_PLANS = [
        BRONZE,
        SILVER,
        PREMIUM,
        GOLD,
        ULTIMATE,
        ULTIMATE_TRIAL,
        ULTIMATE_TRIAL_PAID_CUSTOMER,
        PREMIUM_TRIAL,
        OPEN_SOURCE
      ].freeze
      FREE_TRIAL_PLANS = [ULTIMATE_TRIAL, PREMIUM_TRIAL].freeze
      EE_ALL_PLANS = (EE_DEFAULT_PLANS + PAID_HOSTED_PLANS).freeze
      PLANS_ELIGIBLE_FOR_TRIAL = EE_DEFAULT_PLANS
      TOP_PLANS = [GOLD, ULTIMATE, OPEN_SOURCE].freeze
      CURRENT_ACTIVE_PLANS = [FREE, PREMIUM, ULTIMATE].freeze

      has_many :hosted_subscriptions, class_name: 'GitlabSubscription', foreign_key: 'hosted_plan_id'

      EE::Plan.private_constant :EE_ALL_PLANS, :EE_DEFAULT_PLANS

      scope :with_subscriptions, -> { joins(:hosted_subscriptions) }
      scope :by_namespace, ->(namespace) { where(gitlab_subscriptions: { namespace_id: namespace }) }
      scope :by_distinct_names, ->(names) { by_name(names).distinct }
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :all_plans
      def all_plans
        EE_ALL_PLANS
      end

      override :default_plans
      def default_plans
        EE_DEFAULT_PLANS
      end

      # This always returns an object if running on GitLab.com
      def free
        return unless ::Gitlab.com?

        ::Gitlab::SafeRequestStore.fetch(:plan_free) do
          # find_by allows us to find object (cheaply) against replica DB
          # safe_find_or_create_by does stick to primary DB
          find_by(name: FREE) || safe_find_or_create_by(name: FREE)
        end
      end

      def hosted_plans_for_namespaces(namespaces)
        namespaces = Array(namespaces)

        ::Plan
          .with_subscriptions
          .by_name(PAID_HOSTED_PLANS)
          .by_namespace(namespaces)
          .distinct
          .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422013')
      end
    end

    override :paid?
    def paid?
      PAID_HOSTED_PLANS.include?(name)
    end

    def paid_excluding_trials?
      (PAID_HOSTED_PLANS - FREE_TRIAL_PLANS).include?(name)
    end

    def open_source?
      name == OPEN_SOURCE
    end
  end
end
