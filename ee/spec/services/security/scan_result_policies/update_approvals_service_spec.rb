# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UpdateApprovalsService, feature_category: :security_policy_management do
  describe '#execute' do
    let(:scanners) { %w[dependency_scanning] }
    let(:vulnerabilities_allowed) { 1 }
    let(:severity_levels) { %w[high unknown] }
    let(:vulnerability_states) { %w[detected new_needs_triage new_dismissed] }
    let(:approvals_required) { 2 }

    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:uuids) { Array.new(5) { SecureRandom.uuid } }
    let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, source_project: project, target_project: project,
        source_branch: 'feature', target_branch: 'master')
    end

    let_it_be(:pipeline) do
      create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
        ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
    end

    let_it_be(:target_pipeline) do
      create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
        ref: merge_request.target_branch, sha: merge_request.diff_base_sha)
    end

    let_it_be(:pipeline_scan) do
      create(:security_scan, :succeeded, project: project, pipeline: pipeline, scan_type: 'dependency_scanning')
    end

    let_it_be(:target_scan) do
      create(:security_scan, :succeeded,
        project: project,
        pipeline: target_pipeline,
        scan_type: 'dependency_scanning'
      )
    end

    let_it_be(:pipeline_findings) do
      uuids.map do |uuid|
        create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high', uuid: uuid)
      end
    end

    let_it_be(:scan_result_policy_read, reload: true) { create(:scan_result_policy_read, project: project) }
    let(:last_violation) { merge_request.scan_result_policy_violations.last }

    let!(:report_approver_rule) do
      create(:report_approver_rule, :scan_finding,
        merge_request: merge_request,
        approvals_required: approvals_required,
        scanners: scanners,
        vulnerabilities_allowed: vulnerabilities_allowed,
        severity_levels: severity_levels,
        vulnerability_states: vulnerability_states,
        scan_result_policy_read: scan_result_policy_read
      )
    end

    before do
      allow(pipeline).to receive(:can_store_security_reports?).and_return(true)
    end

    subject(:execute) do
      described_class.new(merge_request: merge_request, pipeline: pipeline).execute
    end

    shared_examples_for 'does not update approvals_required' do
      it do
        expect do
          execute
        end.not_to change { report_approver_rule.reload.approvals_required }
      end
    end

    shared_examples_for 'sets approvals_required to 0' do
      it do
        expect do
          execute
        end.to change { report_approver_rule.reload.approvals_required }.from(2).to(0)
      end
    end

    shared_examples_for 'new vulnerability_states' do |vulnerability_states|
      before do
        report_approver_rule.update!(vulnerability_states: vulnerability_states)
      end

      it 'does not call VulnerabilitiesCountService' do
        expect(Security::ScanResultPolicies::VulnerabilitiesCountService).not_to receive(:new)

        execute
      end
    end

    RSpec.shared_examples_for 'persists violation details' do
      let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] } }

      it 'persists violation details' do
        execute

        expect(last_violation.violation_data)
          .to match(
            'violations' => {
              'scan_finding' => { 'uuids' => expected_violations }
            },
            'context' => expected_context
          )
      end

      context 'when feature flag "save_policy_violation_data" is disabled' do
        before do
          stub_feature_flags(save_policy_violation_data: false)
        end

        it 'does not persist violation details' do
          execute

          expect(last_violation.violation_data).to be_nil
        end
      end
    end

    context 'without persisted policy' do
      let!(:report_approver_rule) { create(:report_approver_rule, :scan_finding, merge_request: merge_request) }

      it 'does not raise' do
        expect { execute }.not_to raise_error
      end
    end

    context 'when approval rules are empty' do
      let!(:report_approver_rule) { nil }

      it 'does not enqueue Security::GeneratePolicyViolationCommentWorker' do
        expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'when there are no violations and pipeline is manual' do
      let_it_be_with_refind(:pipeline) do
        create(:ee_ci_pipeline, :with_dependency_scanning_report,
          project: project,
          status: :manual,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha)
      end

      before do
        create(:security_scan, :succeeded, project: project, pipeline: pipeline, scan_type: 'dependency_scanning')
      end

      it_behaves_like 'sets approvals_required to 0'

      context 'when include_manual_to_pipeline_completion is disabled' do
        before do
          stub_feature_flags(include_manual_to_pipeline_completion: false)
        end

        it_behaves_like 'does not update approvals_required'
      end
    end

    context 'when security scan is removed in current pipeline' do
      let_it_be(:pipeline) { create(:ee_ci_pipeline, :success, project: project, ref: merge_request.source_branch) }

      context 'when approval rule scanners is empty' do
        let(:scanners) { [] }

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', :scan_finding, true
      end

      context 'when scan type matches the approval rule scanners' do
        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', :scan_finding, true

        it 'logs update' do
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              event: 'update_approvals',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              message: 'Evaluating MR approval rules from scan result policies',
              pipeline_ids: [pipeline.id],
              target_pipeline_ids: [target_pipeline.id],
              project_path: project.full_path
            ).and_call_original

          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              event: 'update_approvals',
              approval_rule_id: report_approver_rule.id,
              approval_rule_name: report_approver_rule.name,
              message: 'Updating MR approval rule',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              reason: 'Scanner removed by MR',
              missing_scans: ['dependency_scanning'],
              project_path: project.full_path
            ).and_call_original

          execute
        end

        context 'when policy fails open' do
          before do
            report_approver_rule.scan_result_policy_read.update!(fallback_behavior: { fail: "open" })
          end

          it 'does not block the rule' do
            expect(::Gitlab::AppJsonLogger).not_to receive(:info).with(hash_including(reason: 'Scanner removed by MR'))

            execute
          end
        end

        it 'persists the error in violation data' do
          execute

          expect(last_violation.violation_data)
            .to eq('errors' => [{
              'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_removed],
              'missing_scans' => ['dependency_scanning']
            }])
        end

        context 'when feature flag "save_policy_violation_data" is disabled' do
          before do
            stub_feature_flags(save_policy_violation_data: false)
          end

          it 'does not persist the error in violation data' do
            execute

            expect(last_violation.violation_data).to be_nil
          end
        end
      end

      context 'when scan type does not match the approval rule scanners' do
        let(:scanners) { %w[container_scanning] }

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', :scan_finding, false
      end
    end

    context 'when there are no violated approval rules' do
      let(:vulnerabilities_allowed) { 100 }

      it_behaves_like 'sets approvals_required to 0'
      it_behaves_like 'triggers policy bot comment', :scan_finding, false
      it_behaves_like 'merge request without scan result violations'

      context 'when there are other scan_finding violations' do
        let_it_be(:protected_branch) { create(:protected_branch, project: project, name: 'master') }
        let_it_be(:scan_result_policy_read_other_scan_finding) { create(:scan_result_policy_read, project: project) }
        let_it_be(:approval_project_rule_other) do
          create(:approval_project_rule, :scan_finding, project: project, approvals_required: 1,
            scan_result_policy_read: scan_result_policy_read_other_scan_finding,
            protected_branches: [protected_branch])
        end

        let_it_be(:approver_rule_other) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request, vulnerability_states: ['detected'],
            approval_project_rule: approval_project_rule_other, approvals_required: 1,
            scan_result_policy_read: scan_result_policy_read_other_scan_finding)
        end

        let_it_be_with_reload(:other_violation) do
          create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read_other_scan_finding,
            merge_request: merge_request)
        end

        it_behaves_like 'triggers policy bot comment', :scan_finding, true

        context 'when other violation has not been evaluated yet and has no data' do
          before do
            other_violation.update!(violation_data: nil)
          end

          it_behaves_like 'does not trigger policy bot comment'

          context 'when feature flag "save_policy_violation_data" is disabled' do
            before do
              stub_feature_flags(save_policy_violation_data: false)
            end

            it_behaves_like 'triggers policy bot comment', :scan_finding, true
          end
        end
      end
    end

    context 'when there are no required approvals' do
      let(:approvals_required) { 0 }

      it_behaves_like 'triggers policy bot comment', :scan_finding, true, requires_approval: false
      it_behaves_like 'persists violation details' do
        let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
      end
    end

    context 'when targeting an unprotected branch' do
      let_it_be(:protected_branch) { create(:protected_branch, project: project, name: 'master') }
      let!(:report_approver_project_rule) do
        create(:approval_project_rule, :scan_finding, project: project,
          approvals_required: approvals_required, scan_result_policy_read: scan_result_policy_read,
          protected_branches: [protected_branch])
      end

      let!(:report_approver_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          approval_project_rule: report_approver_project_rule,
          approvals_required: approvals_required, scan_result_policy_read: scan_result_policy_read)
      end

      before do
        merge_request.update!(target_branch: 'non-protected')
      end

      it_behaves_like 'triggers policy bot comment', :scan_finding, false, requires_approval: false
    end

    context 'when target pipeline is nil' do
      let_it_be(:merge_request) do
        create(:merge_request, source_project: project, target_project: project,
          source_branch: 'feature', target_branch: 'target-branch')
      end

      it_behaves_like 'does not update approvals_required'
      it_behaves_like 'triggers policy bot comment', :scan_finding, true
      it_behaves_like 'persists violation details' do
        let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
        let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [] } }
      end
    end

    context 'with merged results pipeline' do
      let_it_be(:merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          :with_dependency_scanning_report,
          merge_request: merge_request,
          project: project,
          ref: merge_request.target_branch,
          sha: Digest::SHA256.hexdigest('target commit'))
      end

      let_it_be(:merged_results_pipeline) do
        create(:ee_ci_pipeline,
          :success,
          source: :merge_request_event,
          merge_request: merge_request,
          project: project,
          source_sha: merge_request.diff_head_sha,
          target_sha: merge_base_pipeline.sha,
          ref: merge_request.merge_ref_path,
          sha: Digest::SHA256.hexdigest('merge commit'))
      end

      let_it_be(:merge_base_pipeline_scan) do
        create(:security_scan, :succeeded, project: project, pipeline: merge_base_pipeline,
          scan_type: 'dependency_scanning')
      end

      let!(:merge_base_pipeline_finding) do
        create(:security_finding, scan: merge_base_pipeline_scan, severity: 'high', scanner: scanner,
          uuid: existing_uuid)
      end

      let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
      let(:vulnerabilities_allowed) { uuids.count - 1 }
      let(:existing_uuid) { uuids.first }

      before do
        merge_request.update_head_pipeline
      end

      context 'when there are no violated approval rules' do
        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', :scan_finding, false
      end

      context 'when there are violated approval rules' do
        let(:existing_uuid) { SecureRandom.uuid }

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', :scan_finding, true

        context 'when no common ancestor pipeline has security reports' do
          before do
            merge_base_pipeline_scan.delete
          end

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'triggers policy bot comment', :scan_finding, true
        end
      end
    end

    context 'when there are findings in the current pipeline exceed the allowed limit' do
      it_behaves_like 'new vulnerability_states', ['new_needs_triage']
      it_behaves_like 'new vulnerability_states', ['new_dismissed']
      it_behaves_like 'new vulnerability_states', %w[new_dismissed new_needs_triage]

      it_behaves_like 'does not update approvals_required'
      it_behaves_like 'triggers policy bot comment', :scan_finding, true

      it_behaves_like 'persists violation details' do
        let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
      end

      context 'when vulnerability_states are new_dismissed' do
        let(:vulnerability_states) { %w[new_dismissed] }

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', :scan_finding, false
      end

      context 'when vulnerability_states are new_needs_triage' do
        let(:vulnerability_states) { %w[new_needs_triage] }

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', :scan_finding, true
      end

      context 'when new findings are introduced to previously existing findings and it exceeds the allowed limit' do
        let(:vulnerabilities_allowed) { 4 }
        let_it_be(:new_finding_uuid) { uuids[4] }
        let_it_be(:previously_existing_finding_uuids) { uuids[0..3] }
        let_it_be(:target_pipeline_findings) do
          create_findings_with_vulnerabilities(target_scan, previously_existing_finding_uuids)
        end

        it 'logs update' do
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              event: 'update_approvals',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              message: 'Evaluating MR approval rules from scan result policies',
              pipeline_ids: [pipeline.id],
              target_pipeline_ids: [target_pipeline.id],
              project_path: project.full_path
            ).and_call_original

          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              event: 'update_approvals',
              approval_rule_id: report_approver_rule.id,
              approval_rule_name: report_approver_rule.name,
              message: 'Updating MR approval rule',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              reason: 'scan_finding rule violated',
              project_path: project.full_path
            ).and_call_original

          execute
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', :scan_finding, true

        it_behaves_like 'persists violation details' do
          let(:expected_violations) do
            {
              'newly_detected' => [new_finding_uuid],
              'previously_existing' => array_including(previously_existing_finding_uuids)
            }
          end
        end

        context 'when there are no new dismissed vulnerabilities' do
          let(:vulnerabilities_allowed) { 0 }

          context 'when vulnerability_states is new_needs_triage' do
            let(:vulnerability_states) { %w[new_needs_triage] }

            it_behaves_like 'new vulnerability_states', ['new_needs_triage']
            it_behaves_like 'does not update approvals_required'
          end

          context 'when vulnerability_states are new_dismissed and new_needs_triage' do
            let(:vulnerability_states) { %w[new_dismissed new_needs_triage] }

            it_behaves_like 'new vulnerability_states', %w[new_dismissed new_needs_triage]
            it_behaves_like 'does not update approvals_required'
          end

          context 'when vulnerability_states are empty array' do
            let(:vulnerability_states) { [] }

            it_behaves_like 'new vulnerability_states', []
            it_behaves_like 'does not update approvals_required'
          end

          context 'when vulnerability_states is new_dismissed' do
            let(:vulnerability_states) { %w[new_dismissed] }

            it_behaves_like 'new vulnerability_states', ['new_dismissed']
            it_behaves_like 'sets approvals_required to 0'
            it_behaves_like 'merge request without scan result violations'
          end
        end

        context 'when there are new dismissed vulnerabilities' do
          let(:vulnerabilities_allowed) { 0 }

          before do
            vulnerability = create(:vulnerability, :dismissed, project: project)
            create(:vulnerabilities_finding, project: project, uuid: new_finding_uuid,
              vulnerability_id: vulnerability.id)
          end

          context 'when vulnerability_states is new_dismissed' do
            let(:vulnerability_states) { %w[new_dismissed] }

            it_behaves_like 'new vulnerability_states', ['new_dismissed']
            it_behaves_like 'does not update approvals_required'

            it_behaves_like 'persists violation details' do
              let(:expected_violations) do
                { 'newly_detected' => [new_finding_uuid] }
              end
            end
          end

          context 'when vulnerability_states are new_dismissed and new_needs_triage' do
            let(:vulnerability_states) { %w[new_dismissed new_needs_triage] }

            it_behaves_like 'new vulnerability_states', %w[new_dismissed new_needs_triage]
            it_behaves_like 'does not update approvals_required'

            it_behaves_like 'persists violation details' do
              let(:expected_violations) do
                { 'newly_detected' => [new_finding_uuid] }
              end
            end
          end

          context 'when vulnerability_states are empty array' do
            let(:vulnerability_states) { [] }

            it_behaves_like 'new vulnerability_states', []
            it_behaves_like 'does not update approvals_required'

            it_behaves_like 'persists violation details' do
              let(:expected_violations) do
                { 'newly_detected' => [new_finding_uuid] }
              end
            end
          end

          context 'when vulnerability_states is new_needs_triage' do
            let(:vulnerability_states) { %w[new_needs_triage] }

            it_behaves_like 'new vulnerability_states', ['new_needs_triage']
            it_behaves_like 'sets approvals_required to 0'
            it_behaves_like 'merge request without scan result violations'
          end
        end

        context 'when the approval rules had approvals removed' do
          let_it_be(:approval_project_rule) do
            create(:approval_project_rule, :scan_finding, project: project, approvals_required: 2,
              scan_result_policy_read: scan_result_policy_read)
          end

          let!(:report_approver_rule) do
            create(:report_approver_rule, :scan_finding,
              approval_project_rule: approval_project_rule,
              merge_request: merge_request,
              approvals_required: 0,
              scanners: scanners,
              vulnerabilities_allowed: vulnerabilities_allowed,
              severity_levels: severity_levels,
              vulnerability_states: vulnerability_states,
              scan_result_policy_read: scan_result_policy_read
            )
          end

          it 'resets the required approvals' do
            expect { execute }.to change { report_approver_rule.reload.approvals_required }.to(2)
          end
        end
      end
    end

    context 'when there are preexisting findings that exceed the allowed limit' do
      context 'when target pipeline is not empty' do
        let_it_be(:pipeline) { create(:ee_ci_pipeline, :success, project: project, ref: merge_request.source_branch) }
        let_it_be(:pipeline_scan) do
          create(:security_scan, :succeeded, pipeline: pipeline, scan_type: 'dependency_scanning')
        end

        let_it_be(:target_pipeline_findings) { create_findings_with_vulnerabilities(target_scan, uuids) }
        let(:vulnerability_states) { %w[detected] }

        # If vulnerability_states only include previously-existing statuses,
        # the updates are handled by SyncPreexistingStatesApprovalRulesService
        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'does not trigger policy bot comment'

        it 'does not add violations' do
          expect { execute }.not_to change { merge_request.scan_result_policy_violations.count }.from(0)
        end

        context 'when vulnerabilities count does not exceed the allowed limit' do
          let(:vulnerabilities_allowed) { 6 }

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'does not trigger policy bot comment'

          it 'does not add violations' do
            expect { execute }.not_to change { merge_request.scan_result_policy_violations.count }.from(0)
          end
        end

        context 'when vulnerability_states has only newly detected' do
          let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', :scan_finding, false
          it_behaves_like 'merge request without scan result violations'
        end

        context 'when vulnerability_states are empty array' do
          let(:vulnerability_states) { [] }

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', :scan_finding, false
          it_behaves_like 'merge request without scan result violations'
        end

        context 'when vulnerability_states include detected' do
          let(:base_states) { %w[detected] }

          [
            %w[new_needs_triage],
            %w[new_dismissed],
            %w[new_needs_triage new_dismissed]
          ].each do |states|
            context "and #{states}" do
              let(:vulnerability_states) { base_states + states }

              it_behaves_like 'does not update approvals_required'
              it_behaves_like 'triggers policy bot comment', :scan_finding, true
              it_behaves_like 'persists violation details' do
                let(:expected_violations) { { 'previously_existing' => array_including(uuids) } }
              end
            end
          end
        end
      end

      context 'when target pipeline is nil' do
        let_it_be(:merge_request) do
          create(:merge_request, source_project: project, target_project: project,
            source_branch: 'feature', target_branch: 'target-branch')
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', :scan_finding, true
        it_behaves_like 'persists violation details' do
          let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
          let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [] } }
        end
      end
    end

    context 'with multiple pipeline' do
      let_it_be(:related_uuids) { Array.new(5) { SecureRandom.uuid } }
      let_it_be(:related_source_pipeline) do
        create(:ee_ci_pipeline, :success,
          project: project,
          source: :schedule,
          ref: merge_request.source_branch,
          sha: pipeline.sha
        )
      end

      let_it_be(:related_target_pipeline) do
        create(:ee_ci_pipeline, :success,
          project: project,
          source: :schedule,
          ref: merge_request.target_branch,
          sha: target_pipeline.sha
        )
      end

      let_it_be(:related_pipeline_scan) do
        create(:security_scan, :succeeded,
          project: project,
          pipeline: related_source_pipeline,
          scan_type: 'dependency_scanning'
        )
      end

      let_it_be(:related_pipeline_findings) do
        related_uuids.each do |uuid|
          create(:security_finding, scan: related_pipeline_scan, scanner: scanner, severity: 'high', uuid: uuid)
        end
      end

      let_it_be(:related_target_scan) do
        create(:security_scan, :succeeded,
          project: project,
          pipeline: related_target_pipeline,
          scan_type: 'dependency_scanning'
        )
      end

      before_all do
        related_uuids.each do |uuid|
          create(:security_finding, scan: related_target_scan, scanner: scanner, severity: 'high', uuid: uuid)

          vulnerability = create(:vulnerability, project: project)
          create(:vulnerabilities_finding, project: project, uuid: uuid, vulnerability: vulnerability)
        end
      end

      context 'when pipeline cannot store security reports' do
        before do
          allow(pipeline).to receive(:can_store_security_reports?).and_return(false)
        end

        it_behaves_like 'does not update approvals_required'
      end

      context 'when security scan is removed in related pipeline' do
        let_it_be(:pipeline) do
          create(:ee_ci_pipeline, :success,
            project: project,
            ref: merge_request.source_branch
          )
        end

        it_behaves_like 'does not update approvals_required'

        it_behaves_like 'triggers policy bot comment', :scan_finding, true
      end
    end

    context 'when the approval rule has vulnerability attributes' do
      let(:report_approver_rule) { nil }
      let_it_be(:policy) do
        create(:scan_result_policy_read, project: project, vulnerability_attributes: { fix_available: true })
      end

      let_it_be(:approval_rule) do
        create(:approval_project_rule, :scan_finding, project: project, scan_result_policy_read: policy)
      end

      let_it_be(:mr_rule) do
        create(:approval_merge_request_rule, :scan_finding, merge_request: merge_request,
          approval_project_rule: approval_rule)
      end

      specify do
        expect(Security::ScanResultPolicies::FindingsFinder).to receive(:new).at_least(:once).with(
          anything,
          anything,
          hash_including(fix_available: true, false_positive: nil)
        ).and_call_original

        execute
      end

      context 'when vulnerability_attributes are nil' do
        before do
          policy.update!(vulnerability_attributes: nil)
        end

        specify do
          expect(Security::ScanResultPolicies::FindingsFinder).to receive(:new).at_least(:once).with(
            anything,
            anything,
            hash_including(fix_available: nil, false_positive: nil)
          ).and_call_original

          execute
        end
      end
    end
  end

  def create_findings_with_vulnerabilities(scan, uuids)
    uuids.each do |uuid|
      create(:security_finding, scan: scan, scanner: scanner, severity: 'high', uuid: uuid)

      vulnerability = create(:vulnerability, project: project)
      create(:vulnerabilities_finding, project: project, scanner: scanner, uuid: uuid, vulnerability: vulnerability)
    end
  end
end
