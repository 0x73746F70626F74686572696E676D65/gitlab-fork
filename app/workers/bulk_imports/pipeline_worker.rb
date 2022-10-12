# frozen_string_literal: true

module BulkImports
  class PipelineWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    FILE_EXTRACTION_PIPELINE_PERFORM_DELAY = 10.seconds

    data_consistency :always
    feature_category :importers
    sidekiq_options retry: false, dead: false
    worker_has_external_dependencies!

    def perform(pipeline_tracker_id, stage, entity_id)
      @pipeline_tracker = ::BulkImports::Tracker
        .with_status(:enqueued)
        .find_by_id(pipeline_tracker_id)

      if pipeline_tracker.present?
        logger.info(
          structured_payload(
            bulk_import_entity_id: pipeline_tracker.entity.id,
            bulk_import_id: pipeline_tracker.entity.bulk_import_id,
            pipeline_name: pipeline_tracker.pipeline_name,
            message: 'Pipeline starting',
            importer: 'gitlab_migration'
          )
        )

        run
      else
        logger.error(
          structured_payload(
            bulk_import_entity_id: entity_id,
            bulk_import_id: bulk_import_id(entity_id),
            pipeline_tracker_id: pipeline_tracker_id,
            message: 'Unstarted pipeline not found',
            importer: 'gitlab_migration'
          )
        )
      end

    ensure
      ::BulkImports::EntityWorker.perform_async(entity_id, stage)
    end

    private

    attr_reader :pipeline_tracker

    def run
      return skip_tracker if pipeline_tracker.entity.failed?

      raise(Pipeline::ExpiredError, 'Pipeline timeout') if job_timeout?
      raise(Pipeline::FailedError, "Export from source instance failed: #{export_status.error}") if export_failed?

      return re_enqueue if export_empty? || export_started?

      pipeline_tracker.update!(status_event: 'start', jid: jid)
      pipeline_tracker.pipeline_class.new(context).run
      pipeline_tracker.finish!
    rescue BulkImports::RetryPipelineError => e
      retry_tracker(e)
    rescue StandardError => e
      fail_tracker(e)
    end

    def bulk_import_id(entity_id)
      @bulk_import_id ||= Entity.find(entity_id).bulk_import_id
    end

    def fail_tracker(exception)
      pipeline_tracker.update!(status_event: 'fail_op', jid: jid)

      logger.error(
        structured_payload(
          bulk_import_entity_id: pipeline_tracker.entity.id,
          bulk_import_id: pipeline_tracker.entity.bulk_import_id,
          pipeline_name: pipeline_tracker.pipeline_name,
          message: exception.message,
          importer: 'gitlab_migration'
        )
      )

      Gitlab::ErrorTracking.track_exception(
        exception,
        bulk_import_entity_id: pipeline_tracker.entity.id,
        bulk_import_id: pipeline_tracker.entity.bulk_import_id,
        pipeline_name: pipeline_tracker.pipeline_name,
        importer: 'gitlab_migration'
      )

      BulkImports::Failure.create(
        bulk_import_entity_id: context.entity.id,
        pipeline_class: pipeline_tracker.pipeline_name,
        pipeline_step: 'pipeline_worker_run',
        exception_class: exception.class.to_s,
        exception_message: exception.message.truncate(255),
        correlation_id_value: Labkit::Correlation::CorrelationId.current_or_new_id
      )
    end

    def logger
      @logger ||= Gitlab::Import::Logger.build
    end

    def re_enqueue(delay = FILE_EXTRACTION_PIPELINE_PERFORM_DELAY)
      self.class.perform_in(
        delay,
        pipeline_tracker.id,
        pipeline_tracker.stage,
        pipeline_tracker.entity.id
      )
    end

    def context
      @context ||= ::BulkImports::Pipeline::Context.new(pipeline_tracker)
    end

    def export_status
      @export_status ||= ExportStatus.new(pipeline_tracker, pipeline_tracker.pipeline_class.relation)
    end

    def file_extraction_pipeline?
      pipeline_tracker.file_extraction_pipeline?
    end

    def job_timeout?
      return false unless file_extraction_pipeline?

      (Time.zone.now - pipeline_tracker.entity.created_at) > Pipeline::NDJSON_EXPORT_TIMEOUT
    end

    def export_failed?
      return false unless file_extraction_pipeline?

      export_status.failed?
    end

    def export_started?
      return false unless file_extraction_pipeline?

      export_status.started?
    end

    def export_empty?
      return false unless file_extraction_pipeline?

      export_status.empty?
    end

    def retry_tracker(exception)
      logger.error(
        structured_payload(
          bulk_import_entity_id: pipeline_tracker.entity.id,
          bulk_import_id: pipeline_tracker.entity.bulk_import_id,
          pipeline_name: pipeline_tracker.pipeline_name,
          message: "Retrying error: #{exception.message}",
          importer: 'gitlab_migration'
        )
      )

      pipeline_tracker.update!(status_event: 'retry', jid: jid)

      re_enqueue(exception.retry_delay)
    end

    def skip_tracker
      logger.info(
        structured_payload(
          bulk_import_entity_id: pipeline_tracker.entity.id,
          bulk_import_id: pipeline_tracker.entity.bulk_import_id,
          pipeline_name: pipeline_tracker.pipeline_name,
          message: 'Skipping pipeline due to failed entity',
          importer: 'gitlab_migration'
        )
      )

      pipeline_tracker.update!(status_event: 'skip', jid: jid)
    end
  end
end
