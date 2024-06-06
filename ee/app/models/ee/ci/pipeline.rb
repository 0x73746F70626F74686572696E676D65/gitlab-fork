# frozen_string_literal: true

module EE
  module Ci
    module Pipeline
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        include UsageStatistics

        has_many :vulnerabilities_finding_pipelines, class_name: 'Vulnerabilities::FindingPipeline', inverse_of: :pipeline
        has_many :vulnerability_findings, source: :finding, through: :vulnerabilities_finding_pipelines, class_name: 'Vulnerabilities::Finding'
        has_many :vulnerability_state_transitions, foreign_key: :state_changed_at_pipeline_id, class_name: 'Vulnerabilities::StateTransition', inverse_of: :pipeline

        # Subscriptions to this pipeline
        has_many :downstream_bridges,
          ->(pipeline) { in_partition(pipeline) },
          class_name: '::Ci::Bridge',
          foreign_key: :upstream_pipeline_id,
          partition_foreign_key: :partition_id
        has_many :security_scans, class_name: 'Security::Scan', inverse_of: :pipeline
        has_many :security_findings, class_name: 'Security::Finding', through: :security_scans, source: :findings

        has_one :dast_profiles_pipeline, class_name: 'Dast::ProfilesPipeline', foreign_key: :ci_pipeline_id
        has_one :dast_profile, class_name: 'Dast::Profile', through: :dast_profiles_pipeline, disable_joins: true

        has_one :source_project, class_name: 'Ci::Sources::Project', foreign_key: :pipeline_id

        # Legacy way to fetch security reports based on job name. This has been replaced by the reports feature.
        scope :with_legacy_security_reports, -> do
          joins(:downloadable_artifacts).where(ci_builds: { name: %w[sast secret_detection dependency_scanning container_scanning dast] })
        end

        scope :latest_completed_or_manual_pipeline_ids_per_source, ->(sha) do
          complete_or_manual
            .group(:source)
            .select('max(id) as id')
            .for_sha(sha)
        end

        # This structure describes feature levels
        # to access the file types for given reports
        REPORT_LICENSED_FEATURES = {
          codequality: nil,
          sast: %i[sast],
          secret_detection: %i[secret_detection],
          dependency_scanning: %i[dependency_scanning],
          container_scanning: %i[container_scanning],
          cluster_image_scanning: %i[cluster_image_scanning],
          dast: %i[dast],
          performance: %i[merge_request_performance_metrics],
          browser_performance: %i[merge_request_performance_metrics],
          load_performance: %i[merge_request_performance_metrics],
          license_scanning: %i[license_scanning],
          metrics: %i[metrics_reports],
          requirements: %i[requirements],
          requirements_v2: %i[requirements],
          coverage_fuzzing: %i[coverage_fuzzing],
          api_fuzzing: %i[api_fuzzing]
        }.freeze

        state_machine :status do
          after_transition any => ::Ci::Pipeline.completed_with_manual_statuses do |pipeline|
            next if pipeline.manual? && !pipeline.include_manual_to_pipeline_completion_enabled?
            next unless pipeline.can_store_security_reports?

            pipeline.run_after_commit do
              ::Security::StoreScansWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_statuses do |pipeline|
            next unless pipeline.has_repository_xray_reports?

            pipeline.run_after_commit do
              ::Ai::StoreRepositoryXrayWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_with_manual_statuses do |pipeline|
            next if pipeline.manual? && !pipeline.include_manual_to_pipeline_completion_enabled?
            next if pipeline.can_store_security_reports?
            next if pipeline.child?
            next unless pipeline.default_branch? && pipeline.can_ingest_sbom_reports?

            pipeline.run_after_commit do
              ::Sbom::IngestReportsWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_with_manual_statuses do |pipeline|
            next if pipeline.manual? && !pipeline.include_manual_to_pipeline_completion_enabled?

            pipeline.run_after_commit do
              ::Ci::SyncReportsToReportApprovalRulesWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_statuses do |pipeline|
            pipeline.run_after_commit do
              ::Security::UnenforceablePolicyRulesPipelineNotificationWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.bridgeable_statuses.map(&:to_sym) do |pipeline|
            next unless pipeline.downstream_bridges.any?

            pipeline.run_after_commit do
              ::Ci::PipelineBridgeStatusWorker.perform_async(pipeline.id)
            end
          end

          after_transition any => ::Ci::Pipeline.completed_statuses do |pipeline|
            next unless pipeline.triggers_subscriptions?

            pipeline.run_after_commit do
              ::Ci::TriggerDownstreamSubscriptionsWorker.perform_async(pipeline.id)
            end
          end
        end
      end

      def vulnerability_findings
        return super unless ::Feature.enabled?(:deprecate_vulnerability_occurrence_pipelines, project)

        raise NotImplementedError, 'Use pipeline.project.vulnerability_findings instead'
      end

      def needs_touch?
        updated_at < 5.minutes.ago
      end

      def triggers_subscriptions?
        # Currently we trigger subscriptions only for tags.
        tag? && project_has_subscriptions?
      end

      def security_reports(report_types: [])
        reports_scope = report_types.empty? ? ::Ci::JobArtifact.security_reports : ::Ci::JobArtifact.security_reports(file_types: report_types)
        types_to_collect = report_types.empty? ? ::EE::Enums::Ci::JobArtifact.security_report_file_types : report_types

        ::Gitlab::Ci::Reports::Security::Reports.new(self).tap do |security_reports|
          latest_report_builds_in_self_and_project_descendants(reports_scope).includes(pipeline: { project: :route }).find_each do |build|
            build.collect_security_reports!(security_reports, report_types: types_to_collect)
          end
        end
      end

      def batch_lookup_report_artifact_for_file_types(file_types)
        file_types_to_search = []
        file_types.each do |file_type|
          file_types_to_search.append(file_type) if available_licensed_report_type?(file_type)
        end

        return unless file_types_to_search.present?

        super(file_types_to_search)
      end

      def dependency_list_report
        ::Gitlab::Ci::Reports::DependencyList::Report.new.tap do |dependency_list_report|
          latest_report_builds(::Ci::JobArtifact.of_report_type(:dependency_list)).success.each do |build|
            build.collect_dependency_list_reports!(dependency_list_report)
          end
        end
      end

      def metrics_report
        ::Gitlab::Ci::Reports::Metrics::Report.new.tap do |metrics_report|
          latest_report_builds(::Ci::JobArtifact.of_report_type(:metrics)).each do |build|
            build.collect_metrics_reports!(metrics_report)
          end
        end
      end

      def sbom_reports
        ::Gitlab::Ci::Reports::Sbom::Reports.new.tap do |sbom_reports|
          latest_report_builds(::Ci::JobArtifact.of_report_type(:sbom)).each do |build|
            build.collect_sbom_reports!(sbom_reports)
          end
        end
      end

      ##
      # Check if it's a merge request pipeline with the HEAD of source and target branches
      # TODO: Make `Ci::Pipeline#latest?` compatible with merge request pipelines and remove this method.
      def latest_merged_result_pipeline?
        merged_result_pipeline? &&
          source_sha == merge_request.diff_head_sha &&
          target_sha == merge_request.target_branch_sha
      end

      override :merge_request_event_type
      def merge_request_event_type
        return unless merge_request?

        strong_memoize(:merge_request_event_type) do
          merge_train_pipeline? ? :merge_train : super
        end
      end

      override :retryable?
      def retryable?
        # if a merge train pipeline is complete, retrying jobs won't put it the MR back
        # in the train, this prevents users from uselessly retrying the pipeline.
        return false if merge_train_pipeline? && complete?

        super
      end

      override :merge_train_pipeline?
      def merge_train_pipeline?
        merged_result_pipeline? && merge_train_ref?
      end

      def latest_failed_security_builds
        security_builds.select(&:latest?)
                       .select(&:failed?)
      end

      def license_scan_completed?
        latest_report_builds(::Ci::JobArtifact.of_report_type(:license_scanning)).exists?
      end

      def can_ingest_sbom_reports?
        project.namespace.ingest_sbom_reports_available? && has_sbom_reports?
      end

      def has_sbom_reports?
        complete_or_manual_and_has_reports?(::Ci::JobArtifact.of_report_type(:sbom))
      end

      def can_store_security_reports?
        project.can_store_security_reports? && has_security_reports?
      end

      # We want all the `security_findings` records for a particular pipeline to be stored in
      # the same partition, therefore, we check if the pipeline already has a `security_scan`.
      #
      # - If it has, then we use the partition number of the existing security_scan to make sure
      # that the new `security_findings` will be stored in the same partition with the existing ones.
      # - If it does not have a security_scan yet, then we can basically use the latest partition
      # of the `security_findings` table.
      def security_findings_partition_number
        @security_findings_partition_number ||= security_scans.first&.findings_partition_number || Security::Finding.active_partition_number
      end

      def has_security_findings?
        security_findings.exists?
      end

      def has_security_findings_in_self_and_descendants?
        Security::Finding.by_project_id_and_pipeline_ids(project_id, self_and_project_descendants.pluck(:id)).exists?
      end

      def triggered_for_ondemand_dast_scan?
        ondemand_dast_scan? && parameter_source?
      end

      def has_security_report_ingestion_warnings?
        security_scans.with_warnings.exists?
      end

      def has_security_report_ingestion_errors?
        security_scans.with_errors.exists?
      end

      def total_ci_minutes_consumed
        ::Gitlab::Ci::Minutes::PipelineConsumption.new(self).amount
      end

      def security_scan_types
        security_scans.pluck(:scan_type)
      end

      def self_and_descendant_security_scans
        Security::Scan.where(pipeline_id: self_and_project_descendants.pluck(:id))
      end

      def has_security_reports?
        security_and_license_scanning_file_types = EE::Enums::Ci::JobArtifact.security_report_file_types | %w[license_scanning]

        complete_or_manual_and_has_reports?(::Ci::JobArtifact.with_file_types(security_and_license_scanning_file_types))
      end

      def has_repository_xray_reports?
        complete_and_has_reports?(::Ci::JobArtifact.repository_xray_reports)
      end

      def has_all_security_policies_reports?
        can_store_security_reports? && can_ingest_sbom_reports?
      end

      # All opened merge requests for which the current pipeline that runs/ran for the head commit
      def opened_merge_requests_with_head_sha
        all_merge_requests.opened.select { |merge_request| merge_request.diff_head_pipeline?(self) }
      end

      def merge_requests_as_base_pipeline
        merge_request_diffs = ::MergeRequestDiff.where(project_id: project_id, base_commit_sha: sha)
        project.merge_requests.opened.where(id: merge_request_diffs.select(:merge_request_id))
      end

      private

      def project_has_subscriptions?
        project.feature_available?(:ci_project_subscriptions) &&
          project.downstream_project_subscriptions.any?
      end

      def merge_train_ref?
        ::MergeRequest.merge_train_ref?(ref)
      end

      def available_licensed_report_type?(file_type)
        feature_names = REPORT_LICENSED_FEATURES.fetch(file_type)
        feature_names.nil? || feature_names.any? { |feature| project.feature_available?(feature) }
      end

      def security_builds
        @security_builds ||= ::Security::SecurityJobsFinder.new(pipeline: self).execute
      end
    end
  end
end
