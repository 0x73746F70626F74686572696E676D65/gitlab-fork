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
          add_on_purchase_for_namespace(namespace).present? &&
          user.can?(:admin_namespace, namespace)
      end

      def self.add_on_purchase_for_namespace(namespace)
        GitlabSubscriptions::DuoPro::NamespaceAddOnPurchasesFinder.new(namespace, trial: true).execute.first
      end
    end
  end
end
