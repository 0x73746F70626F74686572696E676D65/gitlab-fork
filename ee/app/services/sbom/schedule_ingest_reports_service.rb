# frozen_string_literal: true

module Sbom
  class ScheduleIngestReportsService
    include Gitlab::Utils::StrongMemoize

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      return unless pipeline.project.namespace.ingest_sbom_reports_available?
      return unless pipeline.default_branch?
      return unless all_pipelines_complete? && any_pipeline_has_sbom_reports?

      ::Sbom::IngestReportsWorker.perform_async(root_pipeline.id)
    end

    private

    attr_reader :pipeline

    def all_pipelines_complete?
      root_pipeline.self_and_project_descendants.all? { |pipeline| complete?(pipeline) }
    end

    def any_pipeline_has_sbom_reports?
      root_pipeline.builds_in_self_and_project_descendants
        .with_artifacts(::Ci::JobArtifact.of_report_type(:sbom)).any?
    end

    def root_pipeline
      @root_pipeline ||= pipeline.root_ancestor
    end

    def complete?(child_pipeline)
      if manual_completion_enabled?
        child_pipeline.complete_or_manual?
      else
        child_pipeline.complete?
      end
    end

    def manual_completion_enabled?
      pipeline.include_manual_to_pipeline_completion_enabled?
    end
    strong_memoize_attr :manual_completion_enabled?
  end
end
