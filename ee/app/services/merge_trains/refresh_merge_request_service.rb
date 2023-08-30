# frozen_string_literal: true
module MergeTrains
  class RefreshMergeRequestService < BaseService
    include Gitlab::Utils::StrongMemoize

    ProcessError = Class.new(StandardError)

    attr_reader :merge_request

    ##
    # Arguments:
    # merge_request ... The merge request to be refreshed
    def execute(merge_request)
      @merge_request = merge_request

      validate!
      pipeline_created = create_pipeline! if merge_train_car.requires_new_pipeline? || require_recreate?
      merge! if merge_train_car.mergeable?

      success(pipeline_created: pipeline_created.present?)
    rescue ProcessError => e
      abort(e)
    end

    private

    def validate!
      unless project.merge_trains_enabled?
        raise ProcessError, 'project disabled merge trains'
      end

      unless merge_request.on_train?
        raise ProcessError, 'merge request is not on a merge train'
      end

      if !merge_request.open? || merge_request.broken? || merge_request.draft?
        raise ProcessError, 'merge request is not mergeable'
      end

      unless merge_train_car.previous_ref_sha.present?
        raise ProcessError, 'previous ref does not exist'
      end

      if merge_train_car.pipeline_not_succeeded?
        raise ProcessError, 'pipeline did not succeed'
      end
    end

    def create_pipeline!
      result = MergeTrains::CreatePipelineService.new(merge_train_car.project, merge_train_car.user)
        .execute(merge_train_car.merge_request, merge_train_car.previous_ref)

      raise ProcessError, result[:message] unless result[:status] == :success

      pipeline = result[:pipeline]
      cancel_pipeline!(merge_train_car.pipeline, pipeline.id)
      merge_train_car.refresh_pipeline!(pipeline.id)

      pipeline
    end

    def cancel_pipeline!(pipeline, new_pipeline_id)
      ::Ci::CancelPipelineService
        .new(pipeline: pipeline, current_user: nil, auto_canceled_by_pipeline_id: new_pipeline_id)
        .force_execute
    rescue ActiveRecord::StaleObjectError
      # Often the pipeline has already been canceled by the auto-cancellation
      # mechanism when new pipelines for the same ref are created.
      # In this case, we can ignore the exception as it's already canceled.
    end

    def merge!
      merge_train_car.start_merge!

      merge_options = { skip_discussions_check: true, check_mergeability_retry_lease: true }

      if project.merge_requests_ff_only_enabled && Feature.enabled?(:fast_forward_merge_trains_support, project)
        merge_options[:merge_strategy] = MergeRequests::MergeStrategies::FromTrainRef
      end

      MergeRequests::MergeService.new(project: project, current_user: merge_user, params: merge_request.merge_params.with_indifferent_access)
        .execute(merge_request, **merge_options)

      raise ProcessError, "failed to merge. #{merge_request.merge_error}" unless merge_request.merged?

      merge_train_car.finish_merge!
    end

    def merge_train_car
      merge_request.merge_train_car
    end

    def merge_user
      merge_request.merge_user
    end

    def require_recreate?
      params[:require_recreate]
    end

    def abort(error)
      AutoMerge::MergeTrainService.new(project, merge_user)
        .abort(merge_request, error.message, process_next: false)

      error(error.message)
    end
  end
end
