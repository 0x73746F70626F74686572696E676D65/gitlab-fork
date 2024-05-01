# frozen_string_literal: true

module Groups
  module Settings
    class RolesAndPermissionsController < Groups::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper

      feature_category :user_management

      before_action :authorize_admin_member_roles!
      before_action :ensure_root_group!
      before_action :ensure_custom_roles_available!

      private

      def authorize_admin_member_roles!
        render_404 unless can?(current_user, :admin_member_role, group)
      end

      def ensure_root_group!
        render_404 unless group.root?
      end

      def ensure_custom_roles_available!
        render_404 unless group.licensed_feature_available?(:custom_roles) && gitlab_com_subscription?
      end
    end
  end
end
