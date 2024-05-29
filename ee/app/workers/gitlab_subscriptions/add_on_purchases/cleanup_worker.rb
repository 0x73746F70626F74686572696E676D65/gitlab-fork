# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    class CleanupWorker
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- Context unnecessary

      data_consistency :sticky
      feature_category :subscription_management
      idempotent!

      def perform
        GitlabSubscriptions::AddOnPurchase
          .includes(:add_on, :namespace) # rubocop: disable CodeReuse/ActiveRecord -- Avoid N+1 queries
          .each_batch do |add_on_purchases|
            add_on_purchases.ready_for_cleanup.each do |add_on_purchase|
              add_on_purchase.destroy!
              log_event(add_on_purchase)
            end
          end
      end

      private

      def log_event(add_on_purchase)
        Gitlab::AppLogger.info(
          add_on: add_on_purchase.add_on.name,
          message: 'Removable GitlabSubscriptions::AddOnPurchase was deleted via scheduled CronJob',
          namespace: add_on_purchase.namespace&.path
        )
      end
    end
  end
end
