# frozen_string_literal: true

module Gitlab
  module Ci
    module Parsers
      module Security
        class DependencyList
          CONTAINER_IMAGE_PATH_PREFIX = 'container-image:'

          def initialize(project, sha, pipeline)
            @project = project
            @formatter = Formatters::DependencyList.new(project, sha)
            @pipeline = pipeline
          end

          def parse!(json_data, report)
            report_data = Gitlab::Json.parse(json_data)
            parse_dependency_names(report_data, report)
            parse_vulnerabilities(report)
          end

          def parse_dependency_names(report_data, report)
            report_data.fetch('dependency_files', []).each do |file|
              dependencies = file['dependencies']

              next unless dependencies.is_a?(Array)

              dependencies.each do |dependency|
                report.add_dependency(formatter.format(dependency, file['package_manager'], file['path']))
              end
            end
          end

          def parse_vulnerabilities(report)
            vulnerability_findings.each do |finding|
              dependency = finding.location.dig("dependency")

              next unless dependency

              additional_attrs = { vulnerability_id: finding.vulnerability_id, 'severity' => finding.severity }

              additional_attrs['name'] = finding.name unless finding.metadata['name']

              vulnerability = finding.metadata.merge(additional_attrs)

              report.add_dependency(formatter.format(dependency, '', dependency_path(finding), vulnerability))
            end
          end

          def vulnerability_findings
            if ::Feature.enabled?(:deprecate_vulnerability_occurrence_pipelines, project)
              vulnerability_findings_from_project
            else
              vulnerability_findings_from_pipelines
            end
          end

          def vulnerability_findings_from_pipelines
            pipeline
              .vulnerability_findings
              .by_report_types(%i[container_scanning dependency_scanning])
          end

          def vulnerability_findings_from_project
            project
              .vulnerability_findings
              .by_report_types(%i[container_scanning dependency_scanning])
          end

          def dependency_path(finding)
            return finding.file if finding.dependency_scanning?

            "#{CONTAINER_IMAGE_PATH_PREFIX}#{finding.image}"
          end

          private

          attr_reader :formatter, :pipeline, :project
        end
      end
    end
  end
end
