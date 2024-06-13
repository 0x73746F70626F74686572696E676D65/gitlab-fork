# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoProStatusWidgetPresenter < Gitlab::View::Presenter::Simple
      include Gitlab::Utils::StrongMemoize

      presents ::Namespace, as: :namespace

      def eligible_for_widget?
        ::Feature.enabled?(:duo_pro_trials, user, type: :wip) && duo_pro_trial_add_on_purchase.present?
      end

      def attributes
        {
          duo_pro_trial_status_widget_data_attrs: widget_data_attributes,
          duo_pro_trial_status_popover_data_attrs: popover_data_attributes
        }
      end

      private

      def widget_data_attributes
        {
          container_id: 'duo-pro-trial-status-sidebar-widget',
          widget_url: group_usage_quotas_path(namespace, anchor: 'code-suggestions-usage-tab'),
          trial_days_used: trial_status.days_used,
          trial_duration: trial_status.duration,
          percentage_complete: trial_status.percentage_complete
        }
      end

      def popover_data_attributes
        {
          days_remaining: trial_status.days_remaining,
          trial_end_date: trial_status.ends_on
        }
      end

      def duo_pro_trial_add_on_purchase
        namespace.subscription_add_on_purchases.active.trial.for_gitlab_duo_pro.first
      end
      strong_memoize_attr :duo_pro_trial_add_on_purchase

      def trial_status
        starts_on = duo_pro_trial_add_on_purchase.expires_on - GitlabSubscriptions::Trials::DuoPro::DURATION

        GitlabSubscriptions::TrialStatus.new(starts_on, duo_pro_trial_add_on_purchase.expires_on)
      end
      strong_memoize_attr :trial_status
    end
  end
end
