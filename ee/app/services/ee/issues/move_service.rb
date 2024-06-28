# frozen_string_literal: true

module EE
  module Issues
    module MoveService
      extend ::Gitlab::Utils::Override

      override :update_old_entity
      def update_old_entity
        rewrite_related_vulnerability_issues
        delete_pending_escalations
        super
      end

      override :execute
      def execute(issue, target_project, move_any_issue_type = false)
        new_issue = super(issue, target_project, move_any_issue_type)
        # The epic_issue update is not included in `update_old_entity` because it needs to run in a separate
        # transaction that can be rolled back without aborting the move.
        move_epic_issue(issue, new_issue) if new_entity.persisted?

        new_issue
      end

      private

      def move_epic_issue(original_issue, new_issue)
        return unless epic_issue = original_issue.epic_issue
        return unless can?(current_user, :update_epic, epic_issue.epic.group)
        return unless recreate_epic_issue(epic_issue, new_issue)

        original_entity.reset

        ::Gitlab::UsageDataCounters::IssueActivityUniqueCounter.track_issue_changed_epic_action(
          author: current_user,
          project: target_project
        )

        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_issue_moved_from_project(
          author: current_user,
          namespace: epic_issue.epic.group
        )
      end

      def rewrite_related_vulnerability_issues
        issue_links = Vulnerabilities::IssueLink.for_issue(original_entity)
        issue_links.update_all(issue_id: new_entity.id)
      end

      def delete_pending_escalations
        original_entity.pending_escalations.delete_all(:delete_all)
      end

      def recreate_epic_issue(epic_issue, new_issue)
        ApplicationRecord.transaction do
          new_epic_issue = ::EpicIssue.new(epic: epic_issue.epic, issue: new_issue)

          unless epic_issue.destroy && new_epic_issue.save
            log_error_for(epic_issue, epic_issue.epic)
            log_error_for(new_epic_issue, epic_issue.epic)

            raise ActiveRecord::Rollback
          end

          parent_link = ::WorkItems::ParentLink.find_by_work_item_id(epic_issue.issue_id)
          next true unless parent_link

          new_parent_link = ::WorkItems::ParentLink.new(
            work_item_id: new_issue.id,
            work_item_parent_id: parent_link.work_item_parent_id
          )

          next true if parent_link.destroy && new_parent_link.save

          log_error_for(parent_link, epic_issue.epic)
          log_error_for(new_parent_link, epic_issue.epic)
          log_epic_work_item_sync_error(new_parent_link)
          raise ActiveRecord::Rollback
        end
      end

      def log_error_for(record, affected_epic)
        return unless record.errors.present?

        message = "Cannot create association with epic ID: #{affected_epic.id}. " \
          "Error: #{record.errors.full_messages.to_sentence}"

        log_error(message)
      end

      def log_epic_work_item_sync_error(parent_link)
        ::Gitlab::EpicWorkItemSync::Logger.error(
          message: "Not able to update work item link",
          error_message: parent_link.errors.full_messages.to_sentence,
          work_item_id: original_entity.id
        )
      end
    end
  end
end
