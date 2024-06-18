# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      DURATION_NUMBER = 60
      DURATION = DURATION_NUMBER.days

      def self.eligible_namespace?(namespace_id, eligible_namespaces)
        return true if namespace_id.blank?

        namespace_id.to_i.in?(eligible_namespaces.pluck_primary_key)
      end

      def self.show_duo_pro_discover?(namespace, user)
        return false unless namespace.present?
        return false unless user.present?

        ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          namespace.subscription_add_on_purchases.active.trial.for_gitlab_duo_pro.first.present? &&
          user.can?(:admin_namespace, namespace)
      end
    end
  end
end
