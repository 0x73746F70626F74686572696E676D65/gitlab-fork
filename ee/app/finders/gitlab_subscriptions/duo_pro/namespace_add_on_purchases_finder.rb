# frozen_string_literal: true

module GitlabSubscriptions
  module DuoPro
    class NamespaceAddOnPurchasesFinder
      def initialize(namespace, trial: false, only_active: true)
        @namespace = namespace
        @trial = trial
        @only_active = only_active
      end

      def execute
        # There will only be one, but we want to return a collection here and then consume it outside of this
        items = namespace.subscription_add_on_purchases.for_gitlab_duo_pro
        items = by_active(items)
        by_trial(items)
      end

      private

      attr_reader :namespace, :trial, :only_active

      def by_trial(items)
        return items unless trial

        items.trial
      end

      def by_active(items)
        return items unless only_active

        items.active
      end
    end
  end
end
