# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- TODO refactor to use bounded context
module AutoMerge
  class AddToMergeTrainWhenChecksPassService < AutoMerge::BaseService
    def execute(merge_request)
      super do
        SystemNoteService.add_to_merge_train_when_checks_pass(merge_request, project, current_user,
          merge_request.diff_head_pipeline.sha)
      end
    end

    def process(merge_request)
      logger.info("Processing Automerge - AMTWCP")

      return if merge_request.has_ci_enabled? && !merge_request.diff_head_pipeline_success?

      logger.info("Pipeline Success - AMTWCP")

      return unless merge_request.mergeable?(skip_conflict_check: true)

      logger.info("Merge request mergeable - AMTWCP")

      merge_train_service = AutoMerge::MergeTrainService.new(project, merge_request.merge_user)

      unless merge_train_service.available_for?(merge_request)
        return abort(merge_request,
          'This merge request cannot be added to the merge train')
      end

      merge_train_service.execute(merge_request)
    end

    def cancel(merge_request)
      super do
        SystemNoteService.cancel_add_to_merge_train_when_checks_pass(merge_request, project, current_user)
      end
    end

    def abort(merge_request, reason)
      super do
        SystemNoteService.abort_add_to_merge_train_when_checks_pass(merge_request, project, current_user, reason)
      end
    end

    def available_for?(merge_request)
      super do
        next false unless ::Feature.enabled?(:merge_when_checks_pass_merge_train, merge_request.project)
        next false unless ::Feature.enabled?(:merge_when_checks_pass, merge_request.project)
        next false unless merge_request.has_ci_enabled?
        next false if merge_request.mergeable? && !merge_request.diff_head_pipeline_considered_in_progress?

        merge_request.project.merge_trains_enabled?
      end
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
