# frozen_string_literal: true

module Groups
  module AddOns
    class DiscoverDuoProController < Groups::ApplicationController
      feature_category :onboarding
      urgency :low

      def show
        render_404 unless GitlabSubscriptions::Trials::DuoPro.show_duo_pro_discover?(@group, current_user)
      end
    end
  end
end
