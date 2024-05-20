# frozen_string_literal: true

module Dependencies
  module ExportSerializers
    class ProjectDependenciesService
      def self.execute(dependency_list_export)
        new(dependency_list_export).execute
      end

      def initialize(dependency_list_export)
        @dependency_list_export = dependency_list_export
      end

      def execute
        DependencyListEntity.represent(dependencies_list, serializer_parameters)
      end

      private

      attr_reader :dependency_list_export

      delegate :project, :author, to: :dependency_list_export, private: true

      def dependencies_list
        ::Sbom::DependenciesFinder.new(project).execute
          .with_component
          .with_version
          .with_vulnerabilities
      end

      def report_fetch_service
        @report_fetch_service ||= ::Security::ReportFetchService.new(project, job_artifacts)
      end

      def job_artifacts
        ::Ci::JobArtifact.of_report_type(:dependency_list)
      end

      def serializer_parameters
        {
          request: EntityRequest.new({ project: project, user: author }),
          build: report_fetch_service.build,
          project: project,
          include_vulnerabilities: true
        }
      end
    end
  end
end
