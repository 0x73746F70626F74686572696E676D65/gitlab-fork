# frozen_string_literal: true

module Security
  module Ingestion
    # This service class takes the IDs of recently ingested
    # vulnerabilities for a project which had been previously
    # detected by the same scanner, and marks them as resolved
    # on the default branch if they were not detected again.
    class MarkAsResolvedService
      CVS_SCANNER_EXTERNAL_ID = 'gitlab-sbom-vulnerability-scanner'
      CS_SCANNERS_EXTERNAL_IDS = %w[trivy].freeze
      DS_SCANNERS_EXTERNAL_IDS = %w[gemnasium gemnasium-maven gemnasium-python].freeze

      def self.execute(scanner, ingested_ids)
        new(scanner, ingested_ids).execute
      end

      def initialize(scanner, ingested_ids)
        @scanner = scanner
        @ingested_ids = ingested_ids
      end

      def execute
        return unless scanner

        vulnerability_reads
          .by_scanner(scanner)
          .each_batch { |batch| process_batch(batch) }

        if scanner_for_container_scanning?
          process_existing_cvs_vulnerabilities_for_container_scanning
        elsif scanner_for_dependency_scanning?
          process_existing_cvs_vulnerabilities_for_dependency_scanning
        end
      end

      private

      attr_reader :ingested_ids, :scanner

      delegate :project, to: :scanner, private: true
      delegate :vulnerability_reads, to: :project, private: true

      def process_batch(batch)
        (batch.pluck_primary_key - ingested_ids).then { |missing_ids| mark_as_resolved(missing_ids) }
      end

      def mark_as_resolved(missing_ids)
        return if missing_ids.blank?

        Vulnerability.id_in(missing_ids)
                     .with_resolution(false)
                     .not_requiring_manual_resolution
                     .update_all(resolved_on_default_branch: true)
      end

      def process_existing_cvs_vulnerabilities_for_container_scanning
        vulnerability_reads
          .by_scanner_ids(cvs_scanner_id)
          .with_report_types(:container_scanning)
          .each_batch { |batch| process_batch(batch) }
      end

      def process_existing_cvs_vulnerabilities_for_dependency_scanning
        vulnerability_reads
          .by_scanner_ids(cvs_scanner_id)
          .with_report_types(:dependency_scanning)
          .each_batch { |batch| process_batch(batch) }
      end

      def cvs_scanner_id
        ::Vulnerabilities::Scanner.for_projects(project.id)
          .with_external_id(CVS_SCANNER_EXTERNAL_ID)
          .pluck_primary_key
      end

      def scanner_for_container_scanning?
        scanner.external_id.in?(CS_SCANNERS_EXTERNAL_IDS)
      end

      def scanner_for_dependency_scanning?
        scanner.external_id.in?(DS_SCANNERS_EXTERNAL_IDS)
      end
    end
  end
end
