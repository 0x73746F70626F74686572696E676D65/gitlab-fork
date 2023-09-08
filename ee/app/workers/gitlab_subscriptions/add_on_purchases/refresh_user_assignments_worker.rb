# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    class RefreshUserAssignmentsWorker
      include ::ApplicationWorker

      BATCH_SIZE = 500

      feature_category :seat_cost_management

      data_consistency :sticky
      urgency :low

      deduplicate :until_executed, if_deduplicated: :reschedule_once
      idempotent!

      def perform(root_namespace_id)
        @root_namespace_id = root_namespace_id

        return unless root_namespace && add_on_purchase

        add_on_purchase.assigned_users.each_batch(of: BATCH_SIZE) do |batch, index|
          ineligible_user_ids = filter_ineligible_user_ids(batch.pluck_user_ids)

          batch.for_user_ids(ineligible_user_ids).delete_all

          log_event(index)
        end
      end

      private

      attr_reader :root_namespace_id

      def root_namespace
        @root_namespace ||= Group.find_by_id(root_namespace_id)
      end

      def add_on_purchase
        @add_on_purchase ||= root_namespace.subscription_add_on_purchases.for_code_suggestions.first
      end

      # returns user_ids that are not eligible
      def filter_ineligible_user_ids(user_ids)
        root_namespace.filter_ineligible_user_ids_for_code_suggestions(user_ids)
      end

      def log_event(batch)
        Gitlab::AppLogger.info(
          message: 'AddOnPurchase user assignments refreshed in bulk',
          batch: batch,
          add_on: add_on_purchase.add_on.name,
          namespace: root_namespace.path
        )
      end
    end
  end
end
