# frozen_string_literal: true

module Epics
  module EpicLinks
    class CreateService < IssuableLinks::CreateService
      extend ::Gitlab::Utils::Override

      def execute
        return error(issuables_not_found_message, 404) unless can_access_epic_link?

        if issuable.max_hierarchy_depth_achieved?
          return error("This epic cannot be added. One or more epics would "\
                       "exceed the maximum depth (#{Epic::MAX_HIERARCHY_DEPTH}) "\
                       "from its most distant ancestor.", 409)
        end

        if referenced_issuables.count == 1
          create_single_link
        else
          super
        end
      end

      private

      def can_access_epic_link?(epic = issuable, action: :create)
        return true if params[:synced_epic]

        can?(current_user, :"#{action}_epic_tree_relation", epic)
      end

      def create_single_link
        child_epic = referenced_issuables.first
        return error(issuables_not_found_message, 404) unless can_access_epic_link?(child_epic, action: :admin)

        previous_parent_epic = child_epic.parent

        if linkable_epic?(child_epic) && set_child_epic(child_epic)
          create_notes(child_epic, previous_parent_epic)
          update_inherited_dates(child_epic, affected_epics([previous_parent_epic, child_epic]))
          success(created_references: [child_epic])
        else
          error(child_epic.errors.map(&:message).to_sentence, 409)
        end
      end

      def affected_epics(epics)
        [issuable, epics].flatten.compact.uniq
      end

      def relate_issuables(referenced_epic)
        affected_epics = [issuable]
        previous_parent_epic = referenced_epic.parent

        affected_epics << referenced_epic if previous_parent_epic

        if set_child_epic(referenced_epic)
          create_notes(referenced_epic, previous_parent_epic)
        end

        referenced_epic
      end

      def create_notes(referenced_epic, previous_parent_epic)
        return if importing?(referenced_epic, issuable) || params[:synced_epic]

        SystemNoteService.change_epics_relation(issuable, referenced_epic, current_user, 'relate_epic')

        return unless previous_parent_epic
        return if previous_parent_epic == issuable

        SystemNoteService.move_child_epic_to_new_parent(
          previous_parent_epic: previous_parent_epic,
          child_epic: referenced_epic,
          new_parent_epic: issuable,
          user: current_user
        )
      end

      def set_child_epic(child_epic)
        ::ApplicationRecord.transaction do
          child_epic.parent = issuable
          child_epic.move_to_start

          if child_epic.save
            child_epic.sync_work_item_updated_at if importing?(child_epic, issuable)
            create_synced_work_item_link!(child_epic)
          else
            false
          end
        end
      end

      def linkable_issuables(epics)
        @linkable_issuables ||= epics.select do |epic|
          linkable_epic?(epic)
        end
      end

      def linkable_epic?(epic)
        can_link_epic?(epic) && epic.valid_parent?(parent_epic: issuable)
      end

      def references(extractor)
        extractor.epics
      end

      def extractor_context
        { group: issuable.group }
      end

      def previous_related_issuables
        issuable.children.to_a
      end

      def target_issuable_type
        :epic
      end

      def can_link_epic?(epic)
        return true if can_access_epic_link?(epic, action: :admin)

        epic.errors.add(:parent, _("This epic cannot be added. You don't have access to perform this action."))

        false
      end

      def create_synced_work_item_link!(child_epic)
        return true unless !params[:synced_epic] && issuable.group.epic_sync_to_work_item_enabled?
        return true unless issuable.work_item && child_epic.work_item

        response = ::WorkItems::ParentLinks::CreateService
          .new(issuable.work_item, current_user, { target_issuable: child_epic.work_item, synced_work_item: true })
          .execute

        if response[:status] == :success
          sync_relative_position!(response[:created_references].first, child_epic)
        else
          sync_work_item_parent_error!(child_epic, response[:message])
        end
      end

      def sync_relative_position!(parent_link, child_epic)
        if parent_link.update(relative_position: child_epic.relative_position)
          true
        else
          sync_work_item_parent_error!(child_epic)
        end
      end

      def sync_work_item_parent_error!(child_epic, message = "")
        Gitlab::EpicWorkItemSync::Logger.error(
          message: 'Not able to set epic parent', error_message: message, group_id: issuable.group.id,
          parent_id: issuable.id, child_id: child_epic.id
        )
        raise ActiveRecord::Rollback
      end

      def importing?(epic, issuable)
        epic.importing? || issuable.try(:importing?)
      end

      def skip_epic_dates_syncing?
        params[:synced_epic] && Feature.enabled?(:work_items_rolledup_dates, issuable.group)
      end

      def update_inherited_dates(child_epic, epics)
        return unless update_epic_dates?(epics)

        child_epic.run_after_commit_or_now do
          ::Epics::UpdateDatesService.new(epics).execute
        end
      end

      override :update_epic_dates?
      def update_epic_dates?(_affected_epics)
        return false if skip_epic_dates_syncing?

        super
      end
    end
  end
end
