# frozen_string_literal: true

module Security
  class StoreScansService
    def self.execute(pipeline)
      new(pipeline).execute
    end

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      return if already_purged?

      return old_execute unless pipeline.include_manual_to_pipeline_completion_enabled?

      # StoreGroupedScansService returns true only when it creates a `security_scans` record.
      # To avoid resource wastage we are skipping the reports ingestion when there are no new scans, but
      # we sync the rules as it might cause inconsistent state if we skip.
      results = grouped_report_artifacts.map { |artifacts| StoreGroupedScansService.execute(artifacts) }

      sync_findings_to_approval_rules unless pipeline.default_branch?
      return unless results.any?(true)

      schedule_store_reports_worker
      schedule_scan_security_report_secrets_worker
    end

    def old_execute
      grouped_report_artifacts.each { |artifacts| StoreGroupedScansService.execute(artifacts) }

      schedule_store_reports_worker
      schedule_scan_security_report_secrets_worker
      sync_findings_to_approval_rules unless pipeline.default_branch?
    end

    private

    attr_reader :pipeline

    delegate :project, to: :pipeline, private: true

    def already_purged?
      pipeline.security_scans.purged.any?
    end

    def grouped_report_artifacts
      pipeline.job_artifacts
              .security_reports
              .group_by(&:file_type)
              .select { |file_type, _| parse_report_file?(file_type) }
              .values
    end

    def parse_report_file?(file_type)
      project.feature_available?(Ci::Build::LICENSED_PARSER_FEATURES.fetch(file_type))
    end

    def schedule_store_reports_worker
      return unless pipeline.default_branch?

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(Security::StoreSecurityReportsByProjectWorker.cache_key(project_id: project.id), pipeline.id)
      end

      Security::StoreSecurityReportsByProjectWorker.perform_async(project.id)
    end

    def schedule_scan_security_report_secrets_worker
      ScanSecurityReportSecretsWorker.perform_async(pipeline.id) if revoke_secret_detection_token?
    end

    def revoke_secret_detection_token?
      pipeline.project.public? &&
        ::Gitlab::CurrentSettings.secret_detection_token_revocation_enabled? &&
        secret_detection_scans_found?
    end

    def secret_detection_scans_found?
      pipeline.security_scans.by_scan_types(:secret_detection).any?
    end

    def sync_findings_to_approval_rules
      return unless project.licensed_feature_available?(:security_orchestration_policies)

      Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker.perform_async(pipeline.id)
    end
  end
end
