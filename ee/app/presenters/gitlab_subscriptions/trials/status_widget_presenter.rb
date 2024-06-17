# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class StatusWidgetPresenter < Gitlab::View::Presenter::Simple
      presents ::Namespace, as: :namespace

      TIME_FRAME_AFTER_EXPIRATION = 10.days
      private_constant :TIME_FRAME_AFTER_EXPIRATION

      def eligible_for_widget?
        return true if namespace.trial_active?

        !namespace.paid? && namespace.trial_ends_on && namespace.trial_ends_on > TIME_FRAME_AFTER_EXPIRATION.ago
      end

      def attributes
        {
          trial_status_widget_data_attrs: widget_data_attributes,
          trial_status_popover_data_attrs: popover_data_attributes
        }
      end

      private

      def widget_data_attributes
        {
          container_id: 'trial-status-sidebar-widget',
          plan_name: namespace.gitlab_subscription.plan_title,
          plans_href: group_billings_path(namespace),
          trial_days_used: trial_status.days_used,
          trial_duration: trial_status.duration,
          percentage_complete: trial_status.percentage_complete,
          trial_discover_page_path: group_discover_path(namespace),
          nav_icon_image_path: ActionController::Base.helpers.image_path('illustrations/gitlab_logo.svg')
        }
      end

      def popover_data_attributes
        {
          days_remaining: trial_status.days_remaining,
          trial_end_date: trial_status.ends_on
        }
      end

      def trial_status
        @trial_status ||= GitlabSubscriptions::TrialStatus.new(namespace.trial_starts_on, namespace.trial_ends_on)
      end
    end
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/presenters/jh/gitlab_subscriptions/trials/status_widget_presenter.rb
GitlabSubscriptions::Trials::StatusWidgetPresenter.prepend_mod
