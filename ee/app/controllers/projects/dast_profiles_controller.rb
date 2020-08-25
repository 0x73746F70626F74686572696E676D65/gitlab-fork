# frozen_string_literal: true

module Projects
  class DastProfilesController < Projects::ApplicationController
    before_action do
      push_frontend_feature_flag(:security_on_demand_scans_scanner_profiles, project, default_enabled: false)
      :authorize_read_on_demand_scans!
    end

    def index
    end
  end
end
