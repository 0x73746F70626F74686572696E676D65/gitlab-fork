# frozen_string_literal: true

module Epics
  module RelatedEpicLinks
    class CreateService < IssuableLinks::CreateService
      include UsageDataHelper

      def execute
        return error(issuables_no_permission_error_message, 403) unless can_admin_epic_links?

        ApplicationRecord.transaction do
          result = super

          create_synced_work_item_links! if result[:status] == :success

          result
        end

      rescue Epics::SyncAsWorkItem::SyncAsWorkItemError => error
        Gitlab::ErrorTracking.track_exception(error, epic_id: issuable.id)

        error(_("Couldn't create link due to an internal error."), 422)
      end

      def linkable_issuables(epics)
        @linkable_issuables ||= epics.select { |epic| can?(current_user, :read_epic_link_relation, epic) }
      end

      def previous_related_issuables
        @related_epics ||= issuable.related_epics(current_user).to_a
      end

      private

      def can_admin_epic_links?
        return true if params[:synced_epic]

        can?(current_user, :admin_epic_link_relation, issuable)
      end

      def after_create_for(link)
        track_related_epics_event_for(link_type: params[:link_type], event_type: :added, namespace: issuable.group)
      end

      def references(extractor)
        extractor.epics
      end

      def extractor_context
        { group: issuable.group }
      end

      def target_issuable_type
        :epic
      end

      def link_class
        Epic::RelatedEpicLink
      end

      def create_synced_work_item_links!
        return unless sync_to_work_item?

        result = WorkItems::RelatedWorkItemLinks::CreateService.new(issuable.work_item, current_user,
          {
            target_issuable: referenced_synced_work_items,
            link_type: params[:link_type],
            synced_work_item: true
          }
        ).execute

        return result if result[:status] == :success

        Gitlab::EpicWorkItemSync::Logger.error(
          message: "Not able to create work item links", error_message: result[:message], group_id: issuable.group.id,
          epic_id: issuable.id
        )

        raise Epics::SyncAsWorkItem::SyncAsWorkItemError, result[:message]
      end

      def sync_to_work_item?
        !params[:synced_epic] && issuable.work_item && referenced_issuables.any?(&:issue_id)
      end

      def referenced_synced_work_items
        WorkItem.id_in(referenced_issuables.filter_map(&:issue_id))
      end

      def issuables_no_permission_error_message
        _("Couldn't link epics. You must have at least the Guest role in the epic's group.")
      end

      def create_notes(issuable_link)
        super unless params[:synced_epic]
      end
    end
  end
end
