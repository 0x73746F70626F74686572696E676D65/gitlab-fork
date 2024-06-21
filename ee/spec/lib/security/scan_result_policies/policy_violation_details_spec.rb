# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyViolationDetails, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:policy1) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy2) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:policy3) do
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:approver_rule_policy1) do
    create(:report_approver_rule, :scan_finding, merge_request: merge_request,
      scan_result_policy_read: policy1, name: 'Policy 1')
  end

  let_it_be(:approver_rule_policy2) do
    create(:report_approver_rule, :license_scanning, merge_request: merge_request,
      scan_result_policy_read: policy2, name: 'Policy 2')
  end

  let_it_be_with_reload(:approver_rule_policy3) do
    create(:report_approver_rule, :any_merge_request, merge_request: merge_request,
      scan_result_policy_read: policy3, name: 'Policy 3')
  end

  let_it_be(:uuid) { SecureRandom.uuid }
  let_it_be(:uuid_previous) { SecureRandom.uuid }
  let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
  let_it_be(:pipeline) do
    create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
      ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
      merge_requests_as_head_pipeline: [merge_request])
  end

  let_it_be(:ci_build) { pipeline.builds.first }

  let(:details) { described_class.new(merge_request) }

  def build_violation_details(policy, data)
    create(:scan_result_policy_violation, project: project, merge_request: merge_request,
      scan_result_policy_read: policy, violation_data: data)
  end

  describe '#violations' do
    subject(:violations) { details.violations }

    let(:scan_finding_violation_data) do
      { 'violations' => { 'scan_finding' => { 'newly_detected' => ['uuid'] } } }
    end

    let(:license_scanning_violation_data) do
      { 'violations' => { 'license_scanning' => { 'MIT' => ['A'] } } }
    end

    let(:any_merge_request_violation_data) do
      { 'violations' => { 'any_merge_request' => { 'commits' => true } } }
    end

    where(:policy, :name, :report_type, :data) do
      ref(:policy1) | 'Policy 1' | 'scan_finding' | ref(:scan_finding_violation_data)
      ref(:policy2) | 'Policy 2' | 'license_scanning' | ref(:license_scanning_violation_data)
      ref(:policy3) | 'Policy 3' | 'any_merge_request' | ref(:any_merge_request_violation_data)
    end

    with_them do
      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy, violation_data: data)
      end

      it 'has correct attributes', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.report_type).to eq report_type
        expect(violation.data).to eq data
        expect(violation.scan_result_policy_id).to eq policy.id
      end
    end

    context 'when there is a violation that has no approval rules associated with it' do
      let_it_be(:policy_without_rules) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      before do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_without_rules, violation_data: any_merge_request_violation_data)
      end

      it 'is ignored' do
        expect(violations).to be_empty
      end
    end
  end

  describe '#unique_policy_names' do
    subject(:unique_policy_names) { details.unique_policy_names }

    before do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: policy1)
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: policy2)
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: policy3)
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        scan_result_policy_read: policy3, name: 'Other')
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        scan_result_policy_read: policy3, name: 'Other 2')
    end

    it { is_expected.to contain_exactly 'Policy', 'Other' }

    context 'when filtered by report_type' do
      subject(:unique_policy_names) { details.unique_policy_names(:license_scanning) }

      it { is_expected.to contain_exactly 'Policy' }
    end
  end

  describe 'scan finding violations' do
    let_it_be_with_reload(:policy1_violation) do
      build_violation_details(policy1,
        context: { pipeline_ids: [pipeline.id] },
        violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
      )
    end

    let_it_be_with_reload(:policy1_security_finding) do
      pipeline_scan = create(:security_scan, :succeeded, build: ci_build, scan_type: 'dependency_scanning')
      create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high',
        uuid: uuid, location: { start_line: 3, file: '.env' })
    end

    let_it_be_with_reload(:policy1_vulnerability_finding) do
      create(:vulnerabilities_finding, :with_secret_detection, project: project, scanner: scanner,
        uuid: uuid_previous, name: 'AWS API key')
    end

    before_all do
      # Unrelated violation that is expected to be filtered out
      build_violation_details(policy3, violations: { any_merge_request: { commits: true } })
    end

    describe '#new_scan_finding_violations' do
      let(:violation) { new_scan_finding_violations.first }

      subject(:new_scan_finding_violations) { details.new_scan_finding_violations }

      context 'with additional unrelated violation' do
        before do
          build_violation_details(policy2,
            violations: { scan_finding: { uuids: { previously_existing: [uuid_previous] } } }
          )
        end

        it 'returns only related new scan finding violations', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'with multiple pipelines detecting the same uuid' do
        let_it_be(:other_pipeline) do
          create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
            ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
        end

        before_all do
          pipeline_scan = create(:security_scan, :succeeded, build: other_pipeline.builds.first,
            scan_type: 'dependency_scanning')
          create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high',
            uuid: uuid, location: { start_line: 3, file: '.env' })
          policy1_violation.update!(violation_data: policy1_violation.violation_data.merge(
            context: { pipeline_ids: [pipeline.id, other_pipeline.id] }
          ))
        end

        it 'returns only one violation', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'when multiple policies containing the same uuid' do
        before do
          build_violation_details(policy2,
            context: { pipeline_ids: [pipeline.id] },
            violations: {
              scan_finding: { uuids: { newly_detected: [uuid] } }
            }
          )
        end

        it 'returns de-duplicated violations', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.name).to eq 'Test finding'
          expect(violation.severity).to eq 'high'
          expect(violation.path).to match(/^http.+\.env#L3$/)
          expect(violation.location).to match(file: '.env', start_line: 3)
        end
      end

      context 'when the referenced finding does not contain any finding_data' do
        before do
          policy1_security_finding.update!(finding_data: {})
        end

        it 'returns violations without location, path and name', :aggregate_failures do
          expect(new_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'dependency_scanning'
          expect(violation.severity).to eq 'high'
          expect(violation.name).to be_nil
          expect(violation.path).to be_nil
          expect(violation.location).to be_nil
        end
      end
    end

    describe '#previous_scan_finding_violations' do
      let(:violation) { previous_scan_finding_violations.first }

      subject(:previous_scan_finding_violations) { details.previous_scan_finding_violations }

      context 'with additional unrelated violation' do
        before do
          build_violation_details(policy2,
            context: { pipeline_ids: [pipeline.id] },
            violations: { scan_finding: { uuids: { newly_detected: [uuid] } } }
          )
        end

        it 'returns only related previous scan finding violations', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.severity).to eq 'critical'
          expect(violation.path).to match(/^http.+aws-key\.py#L5$/)
          expect(violation.location).to match(hash_including(file: 'aws-key.py', start_line: 5))
        end
      end

      context 'when multiple policies containing the same uuid' do
        before do
          build_violation_details(policy2,
            violations: {
              scan_finding: { uuids: { previously_existing: [uuid_previous] } }
            }
          )
        end

        it 'returns de-duplicated violations', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.severity).to eq 'critical'
          expect(violation.path).to match(/^http.+aws-key\.py#L5$/)
          expect(violation.location).to match(hash_including(file: 'aws-key.py', start_line: 5))
        end
      end

      context 'when the referenced finding does not contain any raw_metadata' do
        before do
          policy1_vulnerability_finding.update! raw_metadata: {}
        end

        it 'returns violations without location and path', :aggregate_failures do
          expect(previous_scan_finding_violations.size).to eq 1

          expect(violation.report_type).to eq 'secret_detection'
          expect(violation.severity).to eq 'critical'
          expect(violation.name).to eq 'AWS API key'
          expect(violation.path).to be_nil
          expect(violation.location).to eq({})
        end
      end
    end
  end

  describe '#any_merge_request_violations' do
    subject(:violations) { details.any_merge_request_violations }

    before do
      build_violation_details(policy3, violations: { any_merge_request: { commits: commits } })
      # Unrelated violation that is expected to be filtered out
      build_violation_details(policy1,
        context: { pipeline_ids: [pipeline.id] },
        violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
      )
    end

    context 'when commits is boolean' do
      let(:commits) { true }

      it 'returns only any_merge_request violations', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.commits).to eq true
      end
    end

    context 'when commits is array' do
      let(:commits) { ['abcd1234'] }

      it 'returns only any_merge_request violations', :aggregate_failures do
        expect(violations.size).to eq 1

        violation = violations.first
        expect(violation.name).to eq 'Policy'
        expect(violation.commits).to match_array(['abcd1234'])
      end
    end
  end

  describe '#license_scanning_violations' do
    subject(:violations) { details.license_scanning_violations }

    before do
      build_violation_details(policy1, violations: { license_scanning: { 'MIT License' => %w[B C D] } })
    end

    it 'returns list of licenses with dependencies' do
      expect(violations.size).to eq 1
      violation = violations.first
      expect(violation.license).to eq 'MIT License'
      expect(violation.dependencies).to contain_exactly('B', 'C', 'D')
      expect(violation.url).to be_nil
    end

    context 'when software license matching the name exists' do
      before do
        create(:software_license, name: 'MIT License', spdx_identifier: 'MIT')
      end

      it 'includes license URL' do
        violation = violations.first
        expect(violation.url).to eq 'https://spdx.org/licenses/MIT.html'
      end
    end

    context 'when multiple violations exist' do
      before do
        build_violation_details(policy2,
          violations: { license_scanning: { 'MIT License' => %w[A B], 'GPL 3' => %w[A] } }
        )
      end

      it 'merges the licenses and dependencies' do
        expect(violations.size).to eq 2
        expect(violations).to contain_exactly(
          Security::ScanResultPolicies::PolicyViolationDetails::LicenseScanningViolation.new(license: 'GPL 3',
            dependencies: %w[A]),
          Security::ScanResultPolicies::PolicyViolationDetails::LicenseScanningViolation.new(license: 'MIT License',
            dependencies: %w[A B C D])
        )
      end
    end
  end

  describe '#errors' do
    subject(:errors) { details.errors }

    let_it_be_with_reload(:violation1) do
      build_violation_details(policy1,
        'errors' => [
          { 'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_removed], missing_scans: ['secret_detection'] }
        ]
      )
    end

    before_all do
      build_violation_details(policy2,
        'errors' => [
          { 'error' => Security::ScanResultPolicyViolation::ERRORS[:artifacts_missing] }
        ]
      )
    end

    it 'returns associated error messages' do
      expect(errors.size).to eq 2
      expect(errors.pluck(:message)).to contain_exactly(
        'There is a mismatch between the scans of the source and target pipelines. ' \
        'The following scans are missing: Secret detection',
        'Pipeline configuration error: Artifacts required by policy `Policy` could not be found (License scanning).'
      )
    end

    context 'with unsupported error' do
      before do
        violation1.update!(violation_data: { 'errors' => [{ 'error' => 'unsupported' }] })
      end

      it 'results in unknown error message' do
        expect(errors.size).to eq 2
        expect(errors.pluck(:error)).to contain_exactly('UNKNOWN', 'ARTIFACTS_MISSING')
        expect(errors.pluck(:message)).to contain_exactly(
          'Unknown error: unsupported',
          'Pipeline configuration error: Artifacts required by policy `Policy` could not be found (License scanning).'
        )
      end
    end
  end

  describe '#comparison_pipelines' do
    subject(:comparison_pipelines) { details.comparison_pipelines }

    before do
      approver_rule_policy3.update!(report_type: :scan_finding)
      # scan_finding
      build_violation_details(policy1, 'context' => { 'pipeline_ids' => [2, 3], 'target_pipeline_ids' => [1] })
      build_violation_details(policy3, 'context' => { 'pipeline_ids' => [3, 4], 'target_pipeline_ids' => [1, 3] })
      # license_scanning
      build_violation_details(policy2, 'context' => { 'pipeline_ids' => [3, 4], 'target_pipeline_ids' => [1, 2] })
    end

    it 'returns associated, deduplicated pipeline ids grouped by report_type', :aggregate_failures do
      expect(comparison_pipelines).to contain_exactly(
        Security::ScanResultPolicies::PolicyViolationDetails::ComparisonPipelines.new(
          report_type: 'scan_finding', source: [2, 3, 4].to_set, target: [1, 3].to_set
        ),
        Security::ScanResultPolicies::PolicyViolationDetails::ComparisonPipelines.new(
          report_type: 'license_scanning', source: [3, 4].to_set, target: [1, 2].to_set
        )
      )
    end
  end
end
