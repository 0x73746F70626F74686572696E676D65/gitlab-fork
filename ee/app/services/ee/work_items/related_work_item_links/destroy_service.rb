# frozen_string_literal: true

module EE
  module WorkItems
    module RelatedWorkItemLinks
      module DestroyService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        def initialize(issuable, user, params)
          @extra_params = params.delete(:extra_params)

          super
        end

        override :execute
        def execute
          super

        rescue ::WorkItems::SyncAsEpic::SyncAsEpicError => error
          ::Gitlab::ErrorTracking.track_exception(error, work_item_id: work_item.id)

          error(_("Couldn't delete work item link due to an internal error."), 422)
        end

        private

        override :perform_destroy_link
        def perform_destroy_link(link, linked_item)
          return super unless destroy_related_epic_link_for?(link)

          ApplicationRecord.transaction do
            super
            destroy_synced_related_epic_link_for!(link) if link.destroyed?
          end
        end

        override :create_notes
        def create_notes(link)
          super unless sync_work_item?
        end

        override :can_admin_work_item_link?
        def can_admin_work_item_link?(_resource)
          return true if sync_work_item?

          super
        end

        def sync_work_item?
          extra_params&.fetch(:synced_work_item, false)
        end

        def destroy_related_epic_link_for?(link)
          !sync_work_item? &&
            work_item.epic_work_item? &&
            link.synced_related_epic_link
        end

        def destroy_synced_related_epic_link_for!(link)
          result =
            ::Epics::RelatedEpicLinks::DestroyService.new(
              link.synced_related_epic_link,
              work_item.synced_epic,
              current_user,
              synced_epic: true
            ).execute

          return result if result[:status] == :success

          ::Gitlab::EpicWorkItemSync::Logger.error(
            message: 'Not able to destroy related epic links',
            error_message: result[:message],
            group_id: work_item.namespace.id,
            target_id: link.target.id,
            source_id: link.source.id
          )

          raise ::WorkItems::SyncAsEpic::SyncAsEpicError, result[:message]
        end

        attr_reader :extra_params
      end
    end
  end
end
