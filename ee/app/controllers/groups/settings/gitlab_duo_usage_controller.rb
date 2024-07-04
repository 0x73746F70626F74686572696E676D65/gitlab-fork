# frozen_string_literal: true

module Groups
  module Settings
    class GitlabDuoUsageController < Groups::ApplicationController
      feature_category :duo_chat

      include ::Nav::GitlabDuoUsageSettingsPage

      def index
        render_404 unless show_gitlab_duo_usage_menu_item?(group)
      end
    end
  end
end
