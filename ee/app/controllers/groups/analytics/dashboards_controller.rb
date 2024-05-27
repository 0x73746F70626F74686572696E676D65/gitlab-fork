# frozen_string_literal: true

module Groups
  module Analytics
    class DashboardsController < Groups::Analytics::ApplicationController
      include ProductAnalyticsTracking

      before_action { authorize_view_by_action!(:read_group_analytics_dashboards) }
      before_action do
        push_frontend_feature_flag(:ai_impact_analytics_dashboard, @group)
        push_frontend_feature_flag(:enable_vsd_visual_editor, @group)

        @data_source_clickhouse = ::Gitlab::ClickHouse.enabled_for_analytics?(@group)
      end

      layout 'group'
    end
  end
end
