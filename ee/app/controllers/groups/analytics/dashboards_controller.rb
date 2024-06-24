# frozen_string_literal: true

module Groups
  module Analytics
    class DashboardsController < Groups::Analytics::ApplicationController
      include ProductAnalyticsTracking

      before_action { authorize_view_by_action!(:read_group_analytics_dashboards) }
      before_action do
        push_frontend_feature_flag(:enable_vsd_visual_editor, @group)

        [:read_dora4_analytics, :read_cycle_analytics, :read_security_resource].each do |ability|
          push_frontend_ability(ability: ability, resource: @group, user: current_user)
        end

        @data_source_clickhouse = ::Gitlab::ClickHouse.enabled_for_analytics?(@group)
      end

      layout 'group'
    end
  end
end
