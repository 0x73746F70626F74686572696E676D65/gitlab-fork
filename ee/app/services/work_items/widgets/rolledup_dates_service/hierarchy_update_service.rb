# frozen_string_literal: true

module WorkItems
  module Widgets
    module RolledupDatesService
      class HierarchyUpdateService
        SYNC_EPIC_DATE_FIELDS = [
          :start_date,
          :start_date_fixed,
          :start_date_is_fixed,
          :start_date_sourcing_milestone_id,
          :due_date,
          :due_date_fixed,
          :due_date_is_fixed,
          :due_date_sourcing_milestone_id
        ].freeze

        def initialize(work_item, previous_work_item_parent_id = nil)
          @work_item = work_item
          @previous_work_item_parent_id = previous_work_item_parent_id
        end

        def execute
          return if work_item.blank?
          return unless ::Feature.enabled?(:work_items_rolledup_dates, work_item.resource_parent)

          work_item.build_dates_source if work_item.dates_source.blank?

          attributes = attributes_for(:due_date).merge(attributes_for(:start_date))

          ApplicationRecord.transaction do
            work_item.dates_source.update!(attributes.except('issue_id')) unless attributes.blank?
            # Still syncs associated legacy epic fields in case work item
            # toggles both start_date and due_date to fixed
            update_synced_epic!
          end

          update_parent
        end

        private

        attr_reader :work_item

        def attributes_for(field)
          return {} if work_item.dates_source.read_attribute(:"#{field}_is_fixed")

          finder.attributes_for(field).presence || {
            field => nil,
            "#{field}_sourcing_milestone_id": nil,
            "#{field}_sourcing_work_item_id": nil
          }
        end

        def update_synced_epic!
          return unless work_item.synced_epic.present?

          dates_source = work_item.dates_source
          epic = work_item.synced_epic

          epic.assign_attributes(dates_source.slice(SYNC_EPIC_DATE_FIELDS))
          epic.start_date_sourcing_epic_id = dates_source.start_date_sourcing_work_item&.synced_epic&.id
          epic.due_date_sourcing_epic_id = dates_source.due_date_sourcing_work_item&.synced_epic&.id

          epic.save!(touch: false)
        end

        def finder
          @finder ||= WorkItems::Widgets::RolledupDatesFinder.new(work_item)
        end

        def update_parent
          parent_id = @previous_work_item_parent_id || work_item.work_item_parent&.id
          return if parent_id.blank?

          ::WorkItems::RolledupDates::UpdateRolledupDatesWorker.perform_async(parent_id)
        end
      end
    end
  end
end
