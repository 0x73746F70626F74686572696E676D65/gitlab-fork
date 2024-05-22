# frozen_string_literal: true

module Epics
  class CreateService < Epics::BaseService
    prepend RateLimitedService
    include SyncAsWorkItem

    rate_limit key: :issues_create, opts: { scope: [:current_user] }

    def execute
      set_date_params

      epic = group.epics.new

      create(epic)
    end

    private

    # Override this method from issuable_base_service.rb
    # We should call epic.save here to save the object and since
    # transaction_create is using `with_transaction_returning_status`
    def transaction_create(epic)
      work_item = create_work_item_for(epic)
      if work_item.persisted?
        epic.issue_id = work_item.id
        epic.iid = work_item.iid
        epic.created_at = work_item.created_at
      end

      super.tap do |save_result|
        break save_result unless save_result && work_item

        work_item.relative_position = epic.id
        work_item.title_html = epic.title_html
        work_item.description_html = epic.description_html
        work_item.updated_at = epic.updated_at
        work_item.save(touch: false)
      end
    end

    def before_create(epic)
      epic.move_to_start if epic.parent

      # current_user (defined in BaseService) is not available within run_after_commit block
      user = current_user
      epic.run_after_commit do
        NewEpicWorker.perform_async(epic.id, user.id)
      end
    end

    def after_create(epic)
      assign_parent_epic_for(epic)
      assign_child_epic_for(epic)

      epic.run_after_commit_or_now do
        # trigger this event after all actions related to saving an epic are done, after commit is not late enough,
        # because after epic creation transaction is commited there are still things happening related to epic, e.g.
        # some associations are updated/linked to the newly created epic, etc.
        ::Gitlab::EventStore.publish(::Epics::EpicCreatedEvent.new(data: { id: epic.id, group_id: epic.group_id }))
      end
    end

    def set_date_params
      if params[:start_date_fixed] && params[:start_date_is_fixed]
        params[:start_date] = params[:start_date_fixed]
      end

      if params[:due_date_fixed] && params[:due_date_is_fixed]
        params[:end_date] = params[:due_date_fixed]
      end
    end
  end
end
