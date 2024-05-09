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

        load_visualizations

        @data_source_clickhouse = ::Gitlab::ClickHouse.enabled_for_analytics?(@group)
      end

      layout 'group'

      VALUE_STREAM_VISUALIZATIONS_PATH = 'ee/lib/gitlab/analytics/value_stream_dashboard/visualizations/'

      def value_streams_dashboard
        respond_to do |format|
          format.html do
            track_value_streams_event

            render :index
          end
        end
      end

      private

      # TODO: we might be able to remove these load methods now and rely on the graphql queries
      def load_visualizations
        @available_visualizations = [load_yaml_dashboard_config(VALUE_STREAM_VISUALIZATIONS_PATH, "dora_chart.yaml")]
      end

      def load_yaml_dashboard_config(path, file)
        visualizations = YAML.safe_load(
          File.read(Rails.root.join(path, file))
        )

        visualizations[:slug] = file.gsub(".yaml", "")
        visualizations
      end

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
