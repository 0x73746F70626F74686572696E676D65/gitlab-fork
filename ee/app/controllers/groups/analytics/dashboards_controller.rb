# frozen_string_literal: true

module Groups
  module Analytics
    class DashboardsController < Groups::Analytics::ApplicationController
      include ProductAnalyticsTracking

      track_event :value_streams_dashboard,
        name: 'g_metrics_comparison_page',
        action: 'perform_analytics_usage_action',
        label: 'redis_hll_counters.analytics.g_metrics_comparison_page_monthly',
        destinations: %i[redis_hll snowplow]

      before_action { authorize_view_by_action!(:read_group_analytics_dashboards) }
      before_action do
        push_frontend_feature_flag(:ai_impact_analytics_dashboard, @group)
        push_frontend_feature_flag(:enable_vsd_visual_editor, @group)

        @data_source_clickhouse = ::Gitlab::ClickHouse.enabled_for_analytics?(@group)
      end

      layout 'group'

      private

      def tracking_namespace_source
        @group
      end

      def tracking_project_source
        nil
      end

      def track_value_streams_event
        Gitlab::InternalEvents.track_event('value_streams_dashboard_viewed', namespace: @group, user: current_user)
      end
    end
  end
end
