# frozen_string_literal: true

module WorkItems
  module Callbacks
    class RolledupDates < Base
      def after_update_commit
        ::WorkItems::Widgets::RolledupDatesService::HierarchyUpdateService
          .new(work_item)
          .execute
      end
    end
  end
end
