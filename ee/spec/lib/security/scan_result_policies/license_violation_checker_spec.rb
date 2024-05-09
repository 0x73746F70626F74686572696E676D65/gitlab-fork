# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::LicenseViolationChecker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let(:case5) do
    [
      ['GPL v3', 'GNU 3', 'A'],
      ['MIT', 'MIT License', 'B'],
      ['GPL v3', 'GNU 3', 'C'],
      ['Apache 2', 'Apache License 2', 'D']
    ]
  end

  let(:case4) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B'], ['GPL v3', 'GNU 3', 'C']] }
  let(:case3) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B']] }
  let(:case2) { [['GPL v3', 'GNU 3', 'A']] }
  let(:case1) { [] }

  describe 'possible combinations' do
    using RSpec::Parameterized::TableSyntax

    let(:violation1) { { 'GNU 3' => %w[A] } }
    let(:violation2) { { 'GNU 3' => %w[A C] } }
    let(:violation3) { { 'GNU 3' => %w[C] } }
    let(:violation4) { { 'Apache License 2' => %w[D] } }

    subject(:service) { described_class.new(project, pipeline_report, target_branch_report) }

    where(:target_branch, :pipeline_branch, :states, :policy_license, :policy_state, :violated_licenses) do
      ref(:case1) | ref(:case2) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation1)
      ref(:case1) | ref(:case2) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | ref(:violation1)
      ref(:case2) | ref(:case3) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | nil
      ref(:case2) | ref(:case3) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | nil
      ref(:case3) | ref(:case4) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation3)
      ref(:case3) | ref(:case4) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | ref(:violation3)
      ref(:case4) | ref(:case5) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | nil
      ref(:case4) | ref(:case5) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | nil
      ref(:case1) | ref(:case2) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | nil
      ref(:case1) | ref(:case2) | ['detected'] | [nil, 'GNU 3'] | :denied | nil
      ref(:case2) | ref(:case3) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation1)
      ref(:case2) | ref(:case3) | ['detected'] | [nil, 'GNU 3'] | :denied | ref(:violation1)
      ref(:case3) | ref(:case4) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation1)
      ref(:case3) | ref(:case4) | ['detected'] | [nil, 'GNU 3'] | :denied | ref(:violation1)
      ref(:case4) | ref(:case5) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation2)
      ref(:case4) | ref(:case5) | ['detected'] | [nil, 'GNU 3'] | :denied | ref(:violation2)
      ref(:case4) | ref(:case5) | %w[newly_detected detected] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation2)

      ref(:case1) | ref(:case2) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation1)
      ref(:case1) | ref(:case2) | ['newly_detected'] | [nil, 'MIT License'] | :allowed | ref(:violation1)
      ref(:case2) | ref(:case3) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | nil
      ref(:case3) | ref(:case4) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation3)
      ref(:case3) | ref(:case4) | ['newly_detected'] | [nil, 'MIT License'] | :allowed | ref(:violation3)
      ref(:case4) | ref(:case5) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation4)
      ref(:case4) | ref(:case5) | ['newly_detected'] | [nil, 'MIT License'] | :allowed | ref(:violation4)
      ref(:case1) | ref(:case2) | ['detected'] | ['MIT', 'MIT License'] | :allowed | nil
      ref(:case1) | ref(:case2) | ['detected'] | [nil, 'MIT License'] | :allowed | nil
      ref(:case2) | ref(:case3) | ['detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation1)
      ref(:case2) | ref(:case3) | ['detected'] | [nil, 'MIT License'] | :allowed | ref(:violation1)
      ref(:case3) | ref(:case4) | ['detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation1)
      ref(:case3) | ref(:case4) | ['detected'] | [nil, 'MIT License'] | :allowed | ref(:violation1)
      ref(:case4) | ref(:case5) | ['detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation2)
      ref(:case4) | ref(:case5) | ['detected'] | [nil, 'MIT License'] | :allowed | ref(:violation2)
      ref(:case4) | ref(:case5) | %w[newly_detected detected] | ['MIT', 'MIT License'] | :allowed | ref(:violation4)

      ref(:case2) | ref(:case2) | ['detected'] | [nil, 'GPL v3'] | :allowed | nil
    end

    with_them do
      let_it_be(:target_branch_report) { create(:ci_reports_license_scanning_report) }
      let_it_be(:pipeline_report) { create(:ci_reports_license_scanning_report) }

      let(:match_on_inclusion_license) { policy_state == :denied }
      let(:license_states) { states }
      let(:license) { create(:software_license, spdx_identifier: policy_license[0], name: policy_license[1]) }
      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project, license_states: license_states,
          match_on_inclusion_license: match_on_inclusion_license)
      end

      before do
        target_branch.each do |ld|
          target_branch_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end

        pipeline_branch.each do |ld|
          pipeline_report.add_license(id: ld[0], name: ld[1]).add_dependency(name: ld[2])
        end

        create(:software_license_policy, policy_state,
          project: project,
          software_license: license,
          scan_result_policy_read: scan_result_policy_read
        )
      end

      it 'syncs approvals_required' do
        result = service.execute(scan_result_policy_read)

        expect(result).to eq(violated_licenses)
      end
    end
  end
end
