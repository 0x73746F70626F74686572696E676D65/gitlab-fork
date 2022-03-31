# frozen_string_literal: true

module Groups
  module Security
    class VulnerabilitiesController < Groups::ApplicationController
      layout 'group'

      before_action do
        push_frontend_feature_flag(:vulnerability_management_survey, type: :ops, default_enabled: :yaml)
        push_frontend_feature_flag(:vulnerability_report_pagination, current_user, default_enabled: :yaml)
        push_frontend_feature_flag(:vulnerability_report_page_size_selector, default_enabled: :yaml)
      end

      feature_category :vulnerability_management

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
