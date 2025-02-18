# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'security findings finder' do
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:build_1) { create(:ci_build, :success, name: 'dependency_scanning', pipeline: pipeline) }
  let_it_be(:build_2) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
  let_it_be(:artifact_ds) { create(:ee_ci_job_artifact, :dependency_scanning, job: build_1) }
  let_it_be(:artifact_sast) { create(:ee_ci_job_artifact, :sast, job: build_2) }
  let_it_be(:report_ds) { create(:ci_reports_security_report, pipeline: pipeline, type: :dependency_scanning) }
  let_it_be(:report_sast) { create(:ci_reports_security_report, pipeline: pipeline, type: :sast) }

  let(:severity_levels) { nil }
  let(:report_types) { nil }
  let(:scope) { nil }
  let(:scanner) { nil }
  let(:state) { nil }
  let(:sort) { nil }
  let(:service_object) { described_class.new(pipeline, params: params) }
  let(:params) do
    {
      severity: severity_levels,
      report_type: report_types,
      scope: scope,
      scanner: scanner,
      state: state,
      sort: sort
    }
  end

  context 'when the pipeline does not have security findings' do
    describe '#execute' do
      subject { service_object.execute }

      it { is_expected.to be_empty }
    end
  end

  shared_examples 'when the pipeline has security findings' do
    before_all do
      ds_content = File.read(artifact_ds.file.path)
      Gitlab::Ci::Parsers::Security::DependencyScanning.parse!(ds_content, report_ds)
      report_ds.merge!(report_ds)
      sast_content = File.read(artifact_sast.file.path)
      Gitlab::Ci::Parsers::Security::Sast.parse!(sast_content, report_sast)
      report_sast.merge!(report_sast)

      findings = { artifact_ds => report_ds, artifact_sast => report_sast }.collect do |artifact, report|
        scan = create(:security_scan, :latest_successful, scan_type: artifact.job.name, build: artifact.job)
        scanner_external_id = report.scanners.each_value.first.external_id
        scanner = create(:vulnerabilities_scanner, project: pipeline.project, external_id: scanner_external_id)

        report.findings.collect do |finding, index|
          create(
            :security_finding,
            severity: finding.severity,
            uuid: finding.uuid,
            deduplicated: true,
            scan: scan,
            scanner: scanner
          )
        end
      end.flatten

      findings.second.update!(deduplicated: false)

      create(
        :vulnerability_feedback,
        :dismissal,
        project: pipeline.project,
        category: :dependency_scanning,
        finding_uuid: findings.first.uuid
      )

      vulnerability_finding = create(:vulnerabilities_finding, uuid: findings.second.uuid)

      vulnerability = create(:vulnerability, findings: [vulnerability_finding])
      create(:vulnerability_state_transition, vulnerability: vulnerability)
      create(:vulnerabilities_issue_link, vulnerability: vulnerability)
      create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
    end

    describe '#execute' do
      let(:finder_result) { service_object.execute }

      before do
        stub_licensed_features(sast: true, dependency_scanning: true)
      end

      describe 'N+1 queries' do
        it 'does not cause N+1 queries' do
          expect { finder_result }.not_to exceed_query_limit(query_limit)
        end
      end

      describe '#findings' do
        subject { findings.map(&:uuid) }

        context 'with the default parameters' do
          let(:expected_uuids) { Security::Finding.pluck(:uuid) - [Security::Finding.second[:uuid]] }

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the uuid is provided' do
          let(:uuid) { Security::Finding.first[:uuid] }
          let(:params) do
            {
              uuid: uuid
            }
          end

          it { is_expected.to match_array([uuid]) }
        end

        context 'when the `severity_levels` is provided' do
          let(:severity_levels) { [:medium] }
          let(:expected_uuids) { Security::Finding.where(severity: 'medium').pluck(:uuid) }

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the `report_types` is provided' do
          let(:report_types) { :dependency_scanning }
          let(:expected_uuids) do
            Security::Finding.by_scan(Security::Scan.find_by(scan_type: 'dependency_scanning')).pluck(:uuid) -
              [Security::Finding.second[:uuid]]
          end

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the `scope` is provided as `all`' do
          let(:scope) { 'all' }

          let(:expected_uuids) { Security::Finding.pluck(:uuid) - [Security::Finding.second[:uuid]] }

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the `scanner` is provided' do
          let(:scanner) { report_sast.scanners.each_value.first.external_id }
          let(:expected_uuids) { Security::Finding.by_scan(Security::Scan.find_by(scan_type: 'sast')).pluck(:uuid) }

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the `state` is provided' do
          let(:dismissed_finding_uuid) { report_ds.findings.first.uuid }
          let(:state) { :dismissed }

          before do
            vulnerability = create(:vulnerability, :dismissed)

            create(:vulnerabilities_finding, vulnerability: vulnerability, uuid: dismissed_finding_uuid)
          end

          it { is_expected.to eq([dismissed_finding_uuid]) }
        end

        context 'when there is a retried build' do
          let(:retried_build) { create(:ci_build, :success, :retried, name: 'dependency_scanning', pipeline: pipeline) }
          let(:artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: retried_build) }
          let(:report) { create(:ci_reports_security_report, pipeline: pipeline, type: :dependency_scanning) }
          let(:report_types) { :dependency_scanning }
          let(:expected_uuids) do
            Security::Finding.by_scan(Security::Scan.find_by(scan_type: 'dependency_scanning')).pluck(:uuid) -
              [Security::Finding.second[:uuid]]
          end

          before do
            retried_content = File.read(artifact.file.path)
            Gitlab::Ci::Parsers::Security::DependencyScanning.parse!(retried_content, report)
            report.merge!(report)

            scan = create(:security_scan, scan_type: retried_build.name, build: retried_build, latest: false)

            report.findings.each_with_index do |finding, index|
              create(
                :security_finding,
                severity: finding.severity,
                uuid: finding.uuid,
                deduplicated: true,
                scan: scan
              )
            end
          end

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when a build has more than one security report artifacts' do
          let(:report_types) { :secret_detection }
          let(:expected_uuids) { secret_detection_report.findings.map(&:uuid) }
          let(:secret_detection_report) do
            create(:ci_reports_security_report, pipeline: pipeline, type: :secret_detection)
          end

          before do
            scan = create(:security_scan, :latest_successful, scan_type: :secret_detection, build: build_2)
            artifact = create(:ee_ci_job_artifact, :secret_detection, job: build_2)
            report_content = File.read(artifact.file.path)

            Gitlab::Ci::Parsers::Security::SecretDetection.parse!(report_content, secret_detection_report)

            secret_detection_report.findings.each_with_index do |finding, index|
              create(
                :security_finding,
                severity: finding.severity,
                uuid: finding.uuid,
                deduplicated: true,
                scan: scan
              )
            end
          end

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when a vulnerability already exist for a security finding' do
          let!(:vulnerability_finding) do
            create(
              :vulnerabilities_finding,
              :detected,
              uuid: Security::Finding.first.uuid,
              project: pipeline.project
            )
          end

          subject { findings.map(&:vulnerability).first }

          describe 'the vulnerability is included in results' do
            it { is_expected.to eq(vulnerability_finding.vulnerability) }
          end
        end
      end
    end
  end
end
