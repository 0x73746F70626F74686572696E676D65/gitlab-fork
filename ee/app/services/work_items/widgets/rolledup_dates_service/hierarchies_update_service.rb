# frozen_string_literal: true

module WorkItems
  module Widgets
    module RolledupDatesService
      class HierarchiesUpdateService
        BATCH_SIZE = 100

        def initialize(work_items)
          @work_items = work_items
          @finder = finder_class.new(@work_items)
        end

        # rubocop: disable CodeReuse/ActiveRecord -- complex update requires some query methods
        def execute
          return if @work_items.blank?

          @work_items.each_batch(of: BATCH_SIZE) do |batch|
            ensure_dates_sources_exist(batch)
            dates_source = ::WorkItems::DatesSource.work_items_in(batch)

            ::WorkItems::DatesSource.transaction do
              dates_source.update_all([
                %{ (start_date, start_date_sourcing_milestone_id, start_date_sourcing_work_item_id) = (?) },
                join_with_update(finder.minimum_start_date)
              ])

              dates_source.update_all([
                %{ (due_date, due_date_sourcing_milestone_id, due_date_sourcing_work_item_id) = (?) },
                join_with_update(finder.maximum_due_date)
              ])
            end

            update_parents(batch)
          end
        end

        private

        attr_reader :finder

        def ensure_dates_sources_exist(work_items)
          work_items
            .excluding(work_items.joins(:dates_source)) # exclude work items that already have a dates source
            .each(&:create_dates_source)
        end

        def join_with_update(query)
          query.where("#{finder_class::UNION_TABLE_ALIAS}.parent_id = work_item_dates_sources.issue_id")
        end

        # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- the query already uses the batch limited in 100 items
        def update_parents(work_items)
          parent_ids = WorkItems::ParentLink.for_children(work_items).pluck(:work_item_parent_id)
          return if parent_ids.blank?

          ::WorkItems::RolledupDates::UpdateMultipleRolledupDatesWorker.perform_async(parent_ids)
        end
        # rubocop: enable Database/AvoidUsingPluckWithoutLimit
        # rubocop: enable CodeReuse/ActiveRecord

        def finder_class
          ::WorkItems::Widgets::RolledupDatesFinder
        end
      end
    end
  end
end
