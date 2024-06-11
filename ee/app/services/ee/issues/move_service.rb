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
        rewrite_epic_issue(issue, new_issue) if new_entity.persisted?

        new_issue
      end

      private

      def rewrite_epic_issue(original_issue, new_issue)
        return unless epic_issue = original_issue.epic_issue
        return unless can?(current_user, :update_epic, epic_issue.epic.group)
        return unless update_epic_issue(epic_issue, new_issue)

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

      def log_error_for(epic_issue)
        message = "Cannot create association with epic ID: #{epic_issue.epic.id}. " \
          "Error: #{epic_issue.errors.full_messages.to_sentence}"

        log_error(message)
      end

      def rewrite_related_vulnerability_issues
        issue_links = Vulnerabilities::IssueLink.for_issue(original_entity)
        issue_links.update_all(issue_id: new_entity.id)
      end

      def delete_pending_escalations
        original_entity.pending_escalations.delete_all(:delete_all)
      end

      def update_epic_issue(epic_issue, new_issue)
        ApplicationRecord.transaction do
          parent_link = ::WorkItems::ParentLink.for_children(epic_issue.issue).first

          unless epic_issue.update(issue: new_issue)
            log_error_for(epic_issue)

            raise ActiveRecord::Rollback
          end

          unless parent_link&.update(work_item_id: new_issue.id, namespace_id: new_issue.project.namespace_id)
            log_error_for(epic_issue)

            ::Gitlab::EpicWorkItemSync::Logger.error(
              message: "Not able to update work item link",
              error_message: parent_link&.errors&.full_messages&.to_sentence,
              work_item_id: original_entity.id
            )

            raise ActiveRecord::Rollback
          end

          true
        end
      end
    end
  end
end
