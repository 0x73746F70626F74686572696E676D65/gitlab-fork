# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Security::DependencyList, feature_category: :dependency_management do
  let(:parser) { described_class.new(project, sha, pipeline) }
  let(:sha) { '4242424242424242' }
  let(:report) { Gitlab::Ci::Reports::DependencyList::Report.new }

  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, :with_dependency_list_report, project: project) }

  describe '#parse!' do
    using RSpec::Parameterized::TableSyntax

    where(:feature_flag, :feature_flag_stub) do
      :deprecate_vulnerability_occurrence_pipelines | false
      :deprecate_vulnerability_occurrence_pipelines | true
    end

    with_them do
      let(:artifact) { pipeline.job_artifacts.last }

      before do
        stub_feature_flags(feature_flag => feature_flag_stub)

        artifact.each_blob do |blob|
          parser.parse!(blob, report)
        end
      end

      context 'with dependency_list artifact' do
        it 'parses all files' do
          blob_path = "/#{project.full_path}/-/blob/#{sha}/yarn/yarn.lock"

          expect(report.dependencies.size).to eq(21)
          expect(report.dependencies[0][:name]).to eq('mini_portile2')
          expect(report.dependencies[0][:version]).to eq('2.2.0')
          expect(report.dependencies[0][:packager]).to eq('Ruby (Bundler)')
          expect(report.dependencies[0][:location][:path]).to eq('rails/Gemfile.lock')

          expect(report.dependencies[12][:name]).to eq('xml-crypto')
          expect(report.dependencies[12][:version]).to eq('0.8.5')
          expect(report.dependencies[12][:packager]).to eq('JavaScript (Yarn)')
          expect(report.dependencies[12][:location][:blob_path]).to eq(blob_path)
          expect(report.dependencies[12][:location][:top_level]).to be_falsey
          expect(report.dependencies[12][:location][:ancestors]).to be_nil

          expect(report.dependencies[13][:name]).to eq('xml-encryption')
          expect(report.dependencies[13][:version]).to eq('0.7.4')
          expect(report.dependencies[13][:location][:top_level]).to be_truthy
          expect(report.dependencies[13][:location][:ancestors]).to be_nil
        end
      end

      context 'with dependency_scanning dependencies' do
        let_it_be(:vulnerability) { create(:vulnerability, report_type: :dependency_scanning, project: project) }
        let_it_be(:finding) { create(:vulnerabilities_finding, :with_dependency_scanning_metadata, vulnerability: vulnerability, pipeline: pipeline) }

        it 'does not causes N+1 query' do
          control = ActiveRecord::QueryRecorder.new do
            artifact.each_blob do |blob|
              parser.parse!(blob, report)
            end
          end

          vuln2 = create(:vulnerability, report_type: :dependency_scanning, project: project)
          create(:vulnerabilities_finding, :with_dependency_scanning_metadata, package: 'mini_portile2', vulnerability: vuln2, pipeline: pipeline)

          expect do
            ActiveRecord::QueryRecorder.new do
              artifact.each_blob do |blob|
                parser.parse!(blob, report)
              end
            end
          end.not_to exceed_query_limit(control)
        end

        it 'merges vulnerability data' do
          vuln_nokogiri = report.dependencies[1][:vulnerabilities]

          expect(report.dependencies.size).to eq(21)
          expect(vuln_nokogiri.size).to eq(1)
          expect(vuln_nokogiri[0][:name]).to eq('Vulnerabilities in libxml2')
        end

        context 'when severity is not part of metadata' do
          let_it_be(:vuln2) { create(:vulnerability, report_type: :dependency_scanning, project: project) }
          let_it_be(:finding2) { create(:vulnerabilities_finding, :with_dependency_scanning_metadata, vulnerability: vuln2, raw_severity: nil, pipeline: pipeline) }

          it 'returns the correct severity' do
            dependency_for_vuln2 = report.dependencies.flat_map { |dep| dep[:vulnerabilities] }.find { |dep| dep[:id] == vuln2.id }

            expect(dependency_for_vuln2[:severity]).to eq('high')
          end
        end

        context 'with newfound dependency' do
          let_it_be(:other_finding) { create(:vulnerabilities_finding, :with_dependency_scanning_metadata, vulnerability: vulnerability, package: 'giri', pipeline: pipeline) }

          it 'adds new dependency and vulnerability to the report' do
            giri = report.dependencies.detect { |dep| dep[:name] == 'giri' }

            expect(report.dependencies.size).to eq(22)
            expect(giri[:vulnerabilities].size).to eq(1)
          end
        end
      end

      context 'with container_scanning dependencies' do
        let_it_be(:vulnerability) { create(:vulnerability, report_type: :container_scanning, project: project) }
        let_it_be(:finding) { create(:vulnerabilities_finding, :with_container_scanning_metadata, vulnerability: vulnerability, pipeline: pipeline) }

        it 'adds new dependency and vulnerability to the report with modified path' do
          cs_dependency = report.dependencies.detect { |dep| dep[:name] == 'org.apache.logging.log4j:log4j-api' }

          expect(report.dependencies.size).to eq(22)
          expect(cs_dependency[:vulnerabilities].size).to eq(1)
          expect(cs_dependency.dig(:location, :path)).to eq('container-image:package-registry/package:tag')
        end
      end

      context 'with null dependencies' do
        let(:empty_report) { Gitlab::Ci::Reports::DependencyList::Report.new }

        let(:json_data) do
          <<~JSON
        {
          "version": "3.0.0",
          "vulnerabilities": [],
          "remediations": [],
          "dependency_files": [
            {
              "path": "package-lock.json",
              "package_manager": "npm",
              "dependencies": null
            }
          ],
          "scan": {
            "scanner": {
              "id": "",
              "name": "",
              "vendor": {
                "name": ""
              },
              "version": ""
            },
            "type": "",
            "start_time": "2021-12-10T15:32:33",
            "end_time": "2021-12-10T15:32:54",
            "status": "success"
          }
        }
          JSON
        end

        it 'ignores null dependencies' do
          parser.parse!(json_data, empty_report)

          expect(empty_report.dependencies.size).to eq(0)
        end
      end
    end
  end
end
