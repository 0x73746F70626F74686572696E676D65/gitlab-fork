# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoProStatusWidgetBuilder
      include ::Gitlab::Utils::StrongMemoize

      def initialize(user, namespace)
        @user = user
        @namespace = namespace
      end

      def widget_data_attributes
        {
          container_id: 'duo-pro-trial-status-sidebar-widget',
          widget_url: widget_url,
          trial_days_used: trial_status.days_used,
          trial_duration: trial_status.duration,
          percentage_complete: trial_status.percentage_complete
        }
      end

      def show?
        namespace.present? &&
          ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          user.can?(:admin_namespace, namespace) &&
          ::Feature.enabled?(:duo_pro_trials, user, type: :wip) &&
          duo_pro_trial_add_on_purchase.present?
      end

      private

      attr_reader :namespace, :user

      def widget_url
        ::Gitlab::Routing.url_helpers.group_usage_quotas_path(namespace, anchor: 'code-suggestions-usage-tab')
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
