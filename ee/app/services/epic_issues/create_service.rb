# frozen_string_literal: true

module EpicIssues
  class CreateService < IssuableLinks::CreateService
    extend ::Gitlab::Utils::Override

    def initialize(issuable, user, params)
      @synced_epic = params.delete(:synced_epic)

      super
    end

    private

    attr_reader :synced_epic

    # rubocop: disable CodeReuse/ActiveRecord
    def relate_issuables(referenced_issue)
      link = EpicIssue.find_or_initialize_by(issue: referenced_issue)

      params = { user_id: current_user.id }
      params[:original_epic_id] = link.epic_id if link.persisted?

      link.epic = issuable
      link.move_to_start
      schedule_new_link_worker(link, referenced_issue, params)

      transaction_result = ApplicationRecord.transaction do
        # When an EpicIssue gets saved, we validate if the current WorkItems::ParentLink
        # matches the set epic (if one exists).
        # As we change the epic before changing the `ParentLink` it would error.
        # We therefore run this in a transaction and skip the validation.
        link.work_item_syncing = true
        sync_work_item_link!(link) if link.save
      end

      ::GraphqlTriggers.issuable_epic_updated(referenced_issue) if transaction_result

      link
    rescue Epics::SyncAsWorkItem::SyncAsWorkItemError => error
      Gitlab::ErrorTracking.track_exception(error, epic_id: issuable.id)
      link.errors.add(:base, _("Couldn't add issue due to an internal error."))
      link
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def extractor_context
      { group: issuable.group }
    end

    def affected_epics(issues)
      [issuable, Epic.in_issues(issues)].flatten.uniq
    end

    def linkable_issuables(issues)
      @linkable_issues ||= begin
        return issues if synced_epic
        return [] unless can?(current_user, :read_epic, issuable.group)

        projects = issues.map(&:project)
        ::Preloaders::UserMaxAccessLevelInProjectsPreloader.new(projects, current_user).execute
        ::Preloaders::GroupPolicyPreloader.new(projects.filter_map(&:group), current_user).execute

        issues.select do |issue|
          linkable_issue?(issue)
        end
      end
    end

    def linkable_issue?(issue)
      return true if synced_epic

      issue.supports_epic? &&
        can?(current_user, :admin_issue_relation, issue) &&
        previous_related_issuables.exclude?(issue)
    end

    def previous_related_issuables
      @related_issues ||= issuable.issues.to_a
    end

    def schedule_new_link_worker(link, referenced_issue, params)
      return if synced_epic

      link.run_after_commit do
        params.merge!(epic_id: link.epic.id, issue_id: referenced_issue.id)
        Epics::NewEpicIssueWorker.perform_async(params)
      end
    end

    def sync_work_item_link!(epic_issue_link)
      return if synced_epic

      if issuable.group.epic_sync_to_work_item_enabled? && issuable.work_item
        create_synced_work_item_link!(epic_issue_link)
      else
        delete_synced_work_item_link!(epic_issue_link)
      end
    end

    def create_synced_work_item_link!(epic_issue_link)
      child_work_items = WorkItem.id_in(epic_issue_link.issue_id)
      response = ::WorkItems::ParentLinks::CreateService
                   .new(issuable.work_item, current_user, { target_issuable: child_work_items, synced_work_item: true })
                   .execute

      if response[:status] == :success
        sync_relative_position!(epic_issue_link, response[:created_references].first)
      else
        sync_work_item_parent_error!(response[:message], epic_issue_link)
      end
    end

    def delete_synced_work_item_link!(epic_issue_link)
      work_item_link = epic_issue_link.work_item.parent_link

      return true unless work_item_link

      ::WorkItems::ParentLinks::DestroyService.new(
        work_item_link,
        current_user,
        synced_work_item: true
      ).execute
    end

    def sync_relative_position!(epic_issue_link, work_item_link)
      return true unless epic_issue_link && work_item_link
      return true if work_item_link.update(relative_position: epic_issue_link.relative_position)

      sync_work_item_parent_error!(work_item_link.errors.full_messages.to_sentence, epic_issue_link)
    end

    def sync_work_item_parent_error!(message, epic_issue_link)
      Gitlab::EpicWorkItemSync::Logger.error(
        message: 'Not able to sync child issue', error_message: message, group_id: issuable.group.id,
        epic_id: issuable.id, issue_id: epic_issue_link.issue_id
      )

      raise Epics::SyncAsWorkItem::SyncAsWorkItemError, message
    end

    override :update_epic_dates?
    def update_epic_dates?(_affected_epics)
      return false if synced_epic && Feature.enabled?(:work_items_rolledup_dates, issuable.group)

      super
    end
  end
end
