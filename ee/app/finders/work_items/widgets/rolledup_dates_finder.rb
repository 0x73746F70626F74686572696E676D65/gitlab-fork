# frozen_string_literal: true

module WorkItems
  module Widgets
    class RolledupDatesFinder
      UNION_TABLE_ALIAS = :dates_sources_union
      FIELD_ORDER_DIRECTION = { start_date: :asc, due_date: :desc }.freeze

      # rubocop: disable CodeReuse/ActiveRecord -- Complex query building, this won't be reused anywhere else,
      # therefore, moving it to the Model will only increase the indirection.
      def initialize(work_items)
        @work_items_ids =
          if work_items.is_a?(ActiveRecord::Relation)
            work_items.select(:id).arel
          else
            Array.wrap(work_items).map(&:id)
          end
      end

      def minimum_start_date
        build_query_for(:start_date)
      end

      def maximum_due_date
        build_query_for(:due_date)
      end

      def attributes_for(field)
        raise ArgumentError, "unknown field '#{field}'" unless FIELD_ORDER_DIRECTION.key?(field)

        (build_query_for(field).first&.attributes || {}).with_indifferent_access
      end

      private

      def build_query_for(field)
        WorkItems::DatesSource
          .with(issues_cte.to_arel)
          .from_union(
            query_milestones(field),
            query_dates_sources(field),
            query_work_items(field),
            alias_as: UNION_TABLE_ALIAS
          )
          .select(
            :"#{UNION_TABLE_ALIAS}.#{field}",
            :"#{UNION_TABLE_ALIAS}.#{field}_sourcing_milestone_id",
            :"#{UNION_TABLE_ALIAS}.#{field}_sourcing_work_item_id"
          )
          .where.not("#{UNION_TABLE_ALIAS}.#{field}": nil)
          .order("#{UNION_TABLE_ALIAS}.#{field}": FIELD_ORDER_DIRECTION[field])
          .limit(1)
      end

      def query_milestones(field)
        WorkItem
          .joins(:milestone)
          .select(
            WorkItem.arel_table["parent_id"],
            ::Milestone.arel_table[field].as(field.to_s),
            ::Milestone.arel_table[:id].as("#{field}_sourcing_milestone_id"),
            "NULL AS #{field}_sourcing_work_item_id")
      end

      def query_dates_sources(field)
        dates_source = WorkItems::DatesSource.arel_table.alias(:dates_source)

        WorkItem
          .joins(:dates_source)
          .where(dates_source: { "#{field}_is_fixed": true })
          .select(
            WorkItem.arel_table["parent_id"],
            dates_source[field].as(field.to_s),
            "NULL AS #{field}_sourcing_milestone_id",
            dates_source[:issue_id].as("#{field}_sourcing_work_item_id"))
      end

      # Once we migrate all the issues.start/due dates to work_item_dates_source
      # we won't need this anymore.
      def query_work_items(field)
        WorkItem
          .select(
            WorkItem.arel_table["parent_id"],
            WorkItem.arel_table[field].as(field.to_s),
            "NULL AS #{field}_sourcing_milestone_id",
            WorkItem.arel_table[:id].as("#{field}_sourcing_work_item_id"))
      end

      def issues_cte
        @issues_cte ||= Gitlab::SQL::CTE.new(
          :issues,
          WorkItem
            .joins(:parent_link)
            .where(WorkItems::ParentLink.arel_table[:work_item_parent_id].in(@work_items_ids))
            .select(
              WorkItem.arel_table[:id].as("id"),
              WorkItems::ParentLink.arel_table[:work_item_parent_id].as("parent_id"),
              WorkItem.arel_table[:milestone_id].as("milestone_id"),
              WorkItem.arel_table[:start_date].as("start_date"),
              WorkItem.arel_table[:due_date].as("due_date")))
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
