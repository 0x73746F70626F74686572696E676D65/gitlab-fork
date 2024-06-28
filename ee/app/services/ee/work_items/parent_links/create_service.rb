# frozen_string_literal: true

module EE
  module WorkItems
    module ParentLinks
      module CreateService
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          super
        rescue ::WorkItems::SyncAsEpic::SyncAsEpicError => error
          ::Gitlab::ErrorTracking.track_exception(error, work_item_parent_id: issuable.id)

          error(_("Couldn't create link due to an internal error."), 422)
        end

        private

        override :set_parent
        def set_parent(issuable, work_item)
          if issuable.epic_work_item? && !synced_work_item
            ApplicationRecord.transaction do
              parent_link = super
              parent_link.work_item_syncing = true # set this attribute to skip the validation validate_legacy_hierarchy
              create_synced_epic_link!(work_item) if parent_link.save

              parent_link
            end
          else
            super
          end
        end

        override :relate_issuables
        def relate_issuables(work_item)
          return super if synced_work_item
          return super unless sync_epic_link?

          ApplicationRecord.transaction do
            parent_link = super

            sync_relative_position(parent_link) if parent_link

            parent_link
          end
        end

        override :create_notes_and_resource_event
        def create_notes_and_resource_event(work_item, _link)
          return if synced_work_item

          super
        end

        override :can_admin_link?
        def can_admin_link?(work_item)
          return true if synced_work_item

          super
        end

        def create_synced_epic_link!(work_item)
          result = work_item.work_item_type.epic? ? handle_epic_link(work_item) : handle_epic_issue(work_item)

          return result if result[:status] == :success

          ::Gitlab::EpicWorkItemSync::Logger.error(
            message: 'Not able to create work item parent link',
            error_message: result[:message],
            group_id: issuable.namespace.id,
            work_item_parent_id: issuable.id,
            work_item_id: work_item.id
          )
          raise ::WorkItems::SyncAsEpic::SyncAsEpicError, result[:message]
        end

        def sync_relative_position(parent_link)
          if parent_link.work_item.work_item_type.epic? && parent_link.work_item.synced_epic
            parent_link.work_item.synced_epic.update(relative_position: parent_link.relative_position)
          elsif parent_link.work_item.work_item_type.issue?
            epic_issue = EpicIssue.find_by_issue_id(parent_link.work_item.id)
            epic_issue.update(relative_position: parent_link.relative_position) if epic_issue
          end
        end

        def handle_epic_link(work_item)
          success_result = { status: :success }
          legacy_child_epic = work_item.synced_epic
          return success_result unless legacy_child_epic

          if sync_epic_link?
            ::Epics::EpicLinks::CreateService.new(
              issuable.synced_epic,
              current_user,
              { target_issuable: legacy_child_epic, synced_epic: true }
            ).execute
          elsif legacy_child_epic.parent.present?
            ::Epics::EpicLinks::DestroyService.new(legacy_child_epic, current_user, synced_epic: true).execute
          else
            success_result
          end
        end

        def handle_epic_issue(work_item)
          success_result = { status: :success }
          child_issue = ::Issue.find_by_id(work_item.id)
          return success_result unless child_issue

          if sync_epic_link?
            ::EpicIssues::CreateService.new(
              issuable.synced_epic,
              current_user,
              { target_issuable: child_issue, synced_epic: true }
            ).execute
          elsif child_issue.has_epic?
            ::EpicIssues::DestroyService.new(child_issue.epic_issue, current_user, synced_epic: true).execute
          else
            success_result
          end
        end

        def sync_epic_link?
          issuable.synced_epic.present?
        end
      end
    end
  end
end
