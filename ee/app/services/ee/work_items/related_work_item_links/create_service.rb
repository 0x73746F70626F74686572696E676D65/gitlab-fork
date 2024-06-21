# frozen_string_literal: true

module EE
  module WorkItems
    module RelatedWorkItemLinks
      module CreateService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        def initialize(issuable, user, params)
          @synced_work_item = params.delete(:synced_work_item)

          super
        end

        def execute
          if params[:link_type].present? && !link_type_available?
            return error(_('Blocked work items are not available for the current subscription tier'), 403)
          end

          response =
            if sync_related_epic_link?
              ApplicationRecord.transaction do
                result = super

                create_synced_related_epic_link! if result[:status] == :success

                result
              end
            else
              super
            end

          # Needs to be called outside of transaction
          # because it spawns sidekiq jobs.
          create_notes_async if new_links.any?

          response
        rescue ::WorkItems::SyncAsEpic::SyncAsEpicError => error
          ::Gitlab::ErrorTracking.track_exception(error, work_item_id: issuable.id)

          error(_("Couldn't create link due to an internal error."), 422)
        end

        private

        attr_reader :synced_work_item

        override :create_notes_async
        def create_notes_async
          return if synced_work_item

          super
        end

        # This override prevents calling :create_notes_async
        # inside a transaction.
        # Can be removed after migration of epics to work_items.
        override :after_execute
        def after_execute; end

        override :can_admin_work_item_link?
        def can_admin_work_item_link?(work_item)
          return true if synced_work_item

          super
        end

        def link_type_available?
          return true unless [link_class::TYPE_BLOCKS, link_class::TYPE_IS_BLOCKED_BY].include?(params[:link_type])

          issuable.resource_parent.licensed_feature_available?(:blocked_work_items)
        end

        override :linked_ids
        def linked_ids(created_links)
          return super unless params[:link_type] == 'is_blocked_by'

          created_links.collect(&:source_id)
        end

        def create_synced_related_epic_link!
          return unless referenced_synced_epics.any?

          sync_params = {
            link_type: params[:link_type],
            target_issuable: referenced_synced_epics,
            synced_epic: true
          }

          result =
            ::Epics::RelatedEpicLinks::CreateService.new(issuable.synced_epic, current_user, sync_params).execute

          return result if result[:status] == :success

          ::Gitlab::EpicWorkItemSync::Logger.error(
            message: "Not able to create related epic links",
            error_message: result[:message],
            group_id: issuable.namespace.id,
            work_item_id: issuable.id
          )
          raise ::WorkItems::SyncAsEpic::SyncAsEpicError, result[:message]
        end

        def referenced_synced_epics
          referenced_issuables.filter_map(&:synced_epic)
        end

        def sync_related_epic_link?
          !synced_work_item &&
            issuable.epic_work_item? &&
            issuable.namespace.work_item_sync_to_epic_enabled? &&
            issuable.synced_epic.present?
        end
      end
    end
  end
end
