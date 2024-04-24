# frozen_string_literal: true

module Groups
  module Security
    class VulnerabilitiesController < Groups::ApplicationController
      include GovernUsageGroupTracking

      layout 'group'

      feature_category :vulnerability_management
      urgency :low
      track_govern_activity 'security_vulnerabilities', :index, conditions: :dashboard_available?

      before_action do
        push_frontend_feature_flag(:activity_filter_has_mr, @project)
        push_frontend_feature_flag(:activity_filter_has_remediations, @project)
        push_frontend_feature_flag(:group_level_vulnerability_report_grouping, @group)
        push_frontend_feature_flag(:container_scanning_for_registry)
      end

      def index
        render :unavailable unless dashboard_available?
      end

      private

      def dashboard_available?
        can?(current_user, :read_group_security_dashboard, group)
      end
    end
  end
end
