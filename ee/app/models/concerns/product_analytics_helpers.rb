# frozen_string_literal: true

module ProductAnalyticsHelpers
  extend ActiveSupport::Concern

  EVENTS_PER_ADD_ON_PURCHASE = 1_000_000

  def product_analytics_enabled?
    return false unless ::Gitlab::CurrentSettings.product_analytics_enabled?

    return false unless is_a?(Project)
    return false unless licensed_feature_available?(:product_analytics)
    return false unless ::Feature.enabled?(:product_analytics_dashboards, self)

    root_group = group&.root_ancestor
    return false unless root_group.present?
    return false unless Feature.enabled?(:product_analytics_beta_optin, root_group)
    return false unless root_group.product_analytics_enabled

    true
  end

  def product_analytics_stored_events_limit
    return unless Feature.enabled?(:product_analytics_billing, type: :wip)

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
end
