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
        push_frontend_feature_flag(:group_analytics_dashboard_dynamic_vsd, @group)
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
            # TODO: Render the shared analytics app if `group_analytics_dashboard_dynamic_vsd` is enabled
            #       the query params approach for specifying namespaces only applies to the legacy VSD page.
            #       This check handles rendering when we directly
            #       link to `/-/analytics/dashboards/value_streams_dashboard`
            if Feature.enabled?(:group_analytics_dashboard_dynamic_vsd, @group)
              track_value_streams_event

              render :index
            else
              @pointer_project = find_pointer_project

              @namespaces =
                if params[:query].present?
                  paths_array = params[:query].split(",")
                  sources = Route.inside_path(@group.full_path).where(path: paths_array).map(&:source) # rubocop:disable CodeReuse/ActiveRecord

                  sources.map do |source|
                    {
                      name: source.name,
                      full_path: source.full_path,
                      is_project: project?(source)
                    }
                  end
                else
                  []
                end
            end
          end
        end
      end

      private

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

      def find_pointer_project
        project = @group.all_projects.find_by_id(@group.analytics_dashboards_pointer&.target_project_id)
        project&.as_json(only: %w[id name], methods: %w[full_path])
      end

      def project?(source)
        source.model_name.param_key == "project"
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
