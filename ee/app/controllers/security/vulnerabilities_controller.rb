# frozen_string_literal: true

module Security
  class VulnerabilitiesController < ::Security::ApplicationController
    layout 'instance_security'
    include GovernUsageTracking

    track_govern_activity 'security_vulnerabilities', :index

    before_action do
      push_frontend_feature_flag(:group_level_vulnerability_report_grouping, @user, type: :development)
    end

    private

    def tracking_namespace_source
      nil
    end

    def tracking_project_source
      nil
    end
  end
end
