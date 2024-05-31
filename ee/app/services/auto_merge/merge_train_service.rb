# frozen_string_literal: true

#
# Note: This service is called via metaprogramming in AutoMergeService
# which is triggered by the AutoMergeProcessWorker when a pipeline completes
#
module AutoMerge
  class MergeTrainService < AutoMerge::BaseService
    extend Gitlab::Utils::Override

    override :execute
    def execute(merge_request)
      # No-op if already on the train. Especially important because assigning a
      # duplicate has_one association with build_#{association} below would
      # permanently delete any pre-existing one, regardless of whether the new
      # one eventually gets saved. Just destroying a car is not safe and can
      # leave the train in an inconsistent state. See #cancel and #abort for the
      # extra steps necessary.
      return if merge_request.on_train?

      merge_request.build_merge_train_car(
        user: current_user,
        target_project: merge_request.target_project,
        target_branch: merge_request.target_branch
      )
      super do
        SystemNoteService.merge_train(merge_request, project, current_user, merge_request.merge_train_car)
      end
    end

    override :process
    def process(merge_request)
      return unless merge_request.on_train?

      ::MergeTrains::RefreshWorker
        .perform_async(merge_request.target_project_id, merge_request.target_branch)
    end

    override :cancel
    def cancel(merge_request)
      # Before dropping a merge request from a merge train, get the next
      # merge request in order to refresh it later.
      next_car = merge_request.merge_train_car&.next

      super do
        if merge_request.merge_train_car&.destroy
          SystemNoteService.cancel_merge_train(merge_request, project, current_user)
          next_car.outdate_pipeline if next_car
        end
      end
    end

    override :abort
    def abort(merge_request, reason, process_next: true)
      # Before dropping a merge request from a merge train, get the next
      # merge request in order to refresh it later.
      next_car = merge_request.merge_train_car&.next

      super(merge_request, reason) do
        if merge_request.merge_train_car&.destroy
          SystemNoteService.abort_merge_train(merge_request, project, current_user, reason)
          GraphqlTriggers.merge_request_merge_status_updated(merge_request)
          next_car.outdate_pipeline if next_car && process_next
        end
      end
    end

    override :available_for?
    def available_for?(merge_request)
      super do
        next false unless merge_request.project.merge_trains_enabled?

        pipeline = merge_request.diff_head_pipeline
        next false unless pipeline

        if merge_request.auto_merge_when_incomplete_pipeline_succeeds_enabled?
          # We allow blocked pipelines as well when pipelines are not required
          # to succeed, because otherwise the only merge action would be an
          # immediate merge.
          pipeline.complete? ||
            (pipeline.blocked? && !merge_request.only_allow_merge_if_pipeline_succeeds?)
        else
          pipeline.complete?
        end
      end
    end

    private

    override :clearable_auto_merge_parameters
    def clearable_auto_merge_parameters
      super + %w[train_ref]
    end
  end
end
