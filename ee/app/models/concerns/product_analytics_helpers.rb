# frozen_string_literal: true

module ProductAnalyticsHelpers
  extend ActiveSupport::Concern

  EVENTS_PER_ADD_ON_PURCHASE = 1_000_000
  GITLAB_PRODUCT_ANALYTICS_DOMAIN = 'gl-product-analytics.com'

  def product_analytics_enabled?
    return false unless ::Gitlab::CurrentSettings.product_analytics_enabled?

    return false unless is_a?(Project)
    return false unless licensed_feature_available?(:product_analytics)

    root_group = group&.root_ancestor
    return false unless root_group.present?

    true
  end

  def product_analytics_stored_events_limit
    return unless product_analytics_billing_enabled?

    analytics_addon_quantity = GitlabSubscriptions::AddOnPurchase
                                 .active
                                 .for_product_analytics
                                 .by_namespace_id(id)
                                 .sum(:quantity)

    analytics_addon_quantity * EVENTS_PER_ADD_ON_PURCHASE
  end

  def project_value_streams_dashboards_enabled?
    return true unless is_a?(Project)

    Feature.enabled?(:project_analytics_dashboard_dynamic_vsd, self)
  end

  def value_streams_dashboard_available?
    licensed_feature =
      if is_a?(Project)
        :project_level_analytics_dashboard
      else
        :group_level_analytics_dashboard
      end

    licensed_feature_available?(licensed_feature) && project_value_streams_dashboards_enabled?
  end

  def ai_impact_dashboard_available?
    Gitlab::ClickHouse.globally_enabled_for_analytics?
  end

  def product_analytics_dashboards(user)
    ::ProductAnalytics::Dashboard.for(container: self, user: user)
  end

  def product_analytics_funnels
    return [] unless product_analytics_enabled?

    ::ProductAnalytics::Funnel.for_project(self)
  end

  def product_analytics_dashboard(slug, user)
    product_analytics_dashboards(user).find { |dashboard| dashboard&.slug == slug }
  end

  def default_dashboards_configuration_source
    is_a?(Project) ? self : nil
  end

  def product_analytics_initialized?
    has_tracking_key? && !initializing?
  end

  def product_analytics_onboarded?(user)
    return false unless has_tracking_key?
    return false if initializing?
    return false if no_instance_data?(user)

    true
  end

  def has_tracking_key?
    project_setting&.product_analytics_instrumentation_key&.present?
  end

  def initializing?
    !!Gitlab::Redis::SharedState.with { |redis| redis.get("project:#{id}:product_analytics_initializing") }
  end

  def no_instance_data?(user)
    strong_memoize_with(:no_instance_data, self) do
      params = { query: { measures: ['TrackedEvents.count'] }, queryType: 'multi', path: 'load' }
      response = ::ProductAnalytics::CubeDataQueryService.new(container: self,
        current_user: user,
        params: params).execute

      response.error? || response.payload.dig('results', 0, 'data', 0, 'TrackedEvents.count').to_i == 0
    end
  end

  def product_analytics_billing_enabled?
    root_ancestor.present? &&
      ::Feature.enabled?(:product_analytics_billing, root_ancestor, type: :development)
  end

  def connected_to_cluster?
    return false unless is_a?(Project)

    return true unless product_analytics_billing_enabled?

    self_managed_product_analytics_cluster? || product_analytics_add_on_purchased?
  end

  def has_self_managed_collector?(collector_host)
    collector_host.present? && collector_host.exclude?(GITLAB_PRODUCT_ANALYTICS_DOMAIN)
  end

  def custom_dashboard_project?
    return false unless is_a?(Project)

    targeting_dashboards_pointer_projects.where.not(id: id).any?
  end

  private

  def product_analytics_add_on_purchased?
    ::Feature.enabled?(:product_analytics_billing_override, root_ancestor) ||
      ::GitlabSubscriptions::AddOnPurchase.active.for_product_analytics.by_namespace_id(root_ancestor.id).any?
  end

  def self_managed_product_analytics_cluster?
    collector_host.present? && has_self_managed_collector?(collector_host)
  end

  def collector_host
    ::ProductAnalytics::Settings.for_project(self).product_analytics_data_collector_host
  end
end
