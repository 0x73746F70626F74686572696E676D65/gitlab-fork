# frozen_string_literal: true

module WorkItems
  module RolledupDates
    class UpdateMultipleRolledupDatesWorker
      include ApplicationWorker

      # rubocop: disable SidekiqLoadBalancing/WorkerDataConsistency -- this worker updates a nested tree of data
      data_consistency :always
      # rubocop: enable SidekiqLoadBalancing/WorkerDataConsistency
      feature_category :portfolio_management
      idempotent!

      def perform(ids)
        work_items = ::WorkItem.id_in(ids)
        return if work_items.blank?

        ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService
          .new(work_items)
          .execute
      end
    end
  end
end
