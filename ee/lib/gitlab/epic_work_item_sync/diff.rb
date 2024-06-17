# frozen_string_literal: true

module Gitlab
  module EpicWorkItemSync
    class Diff
      BASE_ATTRIBUTES = %w[
        author_id
        closed_at
        closed_by_id
        confidential
        created_at
        description
        external_key
        iid
        imported_from
        last_edited_at
        last_edited_by_id
        state_id
        title
        updated_by_id
      ].freeze

      ALLOWED_TIME_RANGE_S = 1.second

      # strict_equal: true
      #   We expect that a work item is fully synced with the epic, including all relations.
      # strict_equal: false
      #   Allows that relations are partially synced. For example when the backfill did not run yet but we already start
      #   creating related links. We only check against links that have a work item.
      def initialize(epic, work_item, strict_equal: false)
        @epic = epic
        @work_item = work_item
        @strict_equal = strict_equal
        @mismatched_attributes = []
      end

      def attributes
        check_base_attributes
        check_updated_at
        check_namespace

        check_color
        check_parent
        check_child_issues
        check_relative_position
        check_start_date_is_fixed
        check_start_date_fixed
        check_due_date_is_fixed
        check_due_date_fixed
        check_related_epic_links

        mismatched_attributes
      end

      private

      def check_base_attributes
        BASE_ATTRIBUTES.each do |attribute|
          next if epic.attributes[attribute] == work_item.attributes[attribute]

          mismatched_attributes.push(attribute)
        end
      end

      def check_updated_at
        return if (epic.updated_at - work_item.updated_at).abs < ALLOWED_TIME_RANGE_S

        mismatched_attributes.push("updated_at")
      end

      def check_namespace
        mismatched_attributes.push("namespace") if epic.group_id != work_item.namespace_id
      end

      def check_color
        return if epic.color == Epic::DEFAULT_COLOR && work_item.color.nil?
        return if epic.color == work_item.color&.color

        mismatched_attributes.push("color")
      end

      def check_parent
        return if epic.parent.nil? && work_item.work_item_parent.nil?
        return if epic.parent&.issue_id == work_item.work_item_parent&.id

        mismatched_attributes.push("parent_id")
      end

      def check_child_issues
        return if epic.epic_issues.blank? && work_item.child_links.blank?

        epic.epic_issues.each do |epic_issue|
          unless work_item.child_links.for_children(epic_issue.issue_id).exists?
            mismatched_attributes.push("epic_issue")
          end
        end
      end

      def check_relative_position
        # if there is no parent_link there is nothing to compare with
        return if work_item.parent_link.blank?
        return if epic.relative_position == work_item.parent_link.relative_position

        mismatched_attributes.push("relative_position")
      end

      def check_start_date_is_fixed
        return if epic.start_date_is_fixed == work_item.dates_source&.start_date_is_fixed
        return if epic.start_date_is_fixed.nil? && work_item.dates_source.start_date_is_fixed == false

        mismatched_attributes.push("start_date_is_fixed")
      end

      def check_start_date_fixed
        return if epic.start_date_fixed == work_item.dates_source&.start_date_fixed

        mismatched_attributes.push("start_date_fixed")
      end

      def check_due_date_is_fixed
        return if epic.due_date_is_fixed == work_item.dates_source&.due_date_is_fixed
        return if epic.due_date_is_fixed.nil? && work_item.dates_source.due_date_is_fixed == false

        mismatched_attributes.push("due_date_is_fixed")
      end

      def check_due_date_fixed
        return if epic.due_date_fixed == work_item.dates_source&.due_date_fixed

        mismatched_attributes.push("due_date_fixed")
      end

      def check_related_epic_links
        related_epic_issues = epic.unauthorized_related_epics

        related_epic_issue_ids = related_epic_issues.map(&:issue_id)
        related_work_item_ids = work_item.related_issues(authorize: false).filter(&:epic_work_item?).map(&:id)

        return if related_work_item_ids.sort == related_epic_issue_ids.sort

        mismatched_attributes.push("related_links")
      end

      attr_reader :epic, :work_item, :strict_equal
      attr_accessor :mismatched_attributes
    end
  end
end
