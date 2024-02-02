# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UpdateApprovalsService, feature_category: :security_policy_management do
  describe '#execute' do
    let(:scanners) { %w[dependency_scanning] }
    let(:vulnerabilities_allowed) { 1 }
    let(:severity_levels) { %w[high unknown] }
    let(:vulnerability_states) { %w[detected newly_detected] }
    let(:approvals_required) { 2 }

    let_it_be(:uuids) { Array.new(5) { SecureRandom.uuid } }
    let_it_be_with_refind(:merge_request) { create(:merge_request, source_branch: 'feature', target_branch: 'master') }
    let_it_be(:project) { merge_request.project }

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
      create_list(:security_finding, 5, scan: pipeline_scan, severity: 'high') do |finding, i|
        finding.update_column(:uuid, uuids[i])
      end
    end

    let!(:report_approver_rule) do
      create(:report_approver_rule, :scan_finding,
        merge_request: merge_request,
        approvals_required: approvals_required,
        scanners: scanners,
        vulnerabilities_allowed: vulnerabilities_allowed,
        severity_levels: severity_levels,
        vulnerability_states: vulnerability_states,
        scan_result_policy_id: create(:scan_result_policy_read).id
      )
    end

    before do
      create_list(:security_finding, 5, scan: target_scan, severity: 'high') do |finding, i|
        finding.update_column(:uuid, uuids[i])
      end

      create_list(:vulnerabilities_finding, 5, project: project) do |finding, i|
        vulnerability = create(:vulnerability, project: project)
        finding.update_columns(uuid: uuids[i], vulnerability_id: vulnerability.id)
      end

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

    context 'when approval rules are empty' do
      let!(:report_approver_rule) { nil }

      it 'does not enqueue Security::GeneratePolicyViolationCommentWorker' do
        expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

        execute
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
    end

    context 'when there are no required approvals' do
      let(:approvals_required) { 0 }

      it_behaves_like 'triggers policy bot comment', :scan_finding, true, requires_approval: false
    end

    context 'when target pipeline is nil' do
      let_it_be(:merge_request) do
        create(:merge_request, source_branch: 'feature', target_branch: 'target-branch')
      end

      it_behaves_like 'does not update approvals_required'

      it_behaves_like 'triggers policy bot comment', :scan_finding, true
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
        create(:security_finding, scan: merge_base_pipeline_scan, severity: 'high', uuid: existing_uuid)
      end

      let(:vulnerability_states) { %w[newly_detected] }
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

      context 'with feature disabled' do
        before do
          stub_feature_flags(scan_result_policy_merge_base_pipeline: false)
        end

        context 'when most recent security orchestration pipeline lacks SBOM' do
          let_it_be(:pipeline_without_sbom) do
            create(
              :ee_ci_pipeline,
              :success,
              source: :security_orchestration_policy,
              project: project,
              merge_requests_as_head_pipeline: [merge_request],
              ref: merge_request.target_branch,
              sha: merge_request.diff_base_sha)
          end

          let(:existing_uuid) { SecureRandom.uuid }

          it_behaves_like 'sets approvals_required to 0'

          it_behaves_like 'triggers policy bot comment', :scan_finding, false
        end
      end
    end

    context 'when the number of findings in current pipeline exceed the allowed limit' do
      context 'when vulnerability_states has only newly_detected' do
        it_behaves_like 'new vulnerability_states', ['newly_detected']
      end

      context 'when vulnerability_states has only new_needs_triage' do
        it_behaves_like 'new vulnerability_states', ['new_needs_triage']
      end

      context 'when vulnerability_states has only new_dismissed' do
        it_behaves_like 'new vulnerability_states', ['new_dismissed']
      end

      context 'when vulnerability_states are new_dismissed and new_needs_triage' do
        it_behaves_like 'new vulnerability_states', %w[new_dismissed new_needs_triage]
      end

      context 'when vulnerabilities count exceeds the allowed limit' do
        it_behaves_like 'does not update approvals_required'

        it_behaves_like 'triggers policy bot comment', :scan_finding, true
      end

      context 'when new findings are introduced and it exceeds the allowed limit' do
        let(:vulnerabilities_allowed) { 4 }
        let(:new_finding_uuid) { SecureRandom.uuid }

        before do
          finding = pipeline_findings.last
          finding.update_column(:uuid, new_finding_uuid)
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

        context 'when there are no new dismissed vulnerabilities' do
          let(:vulnerabilities_allowed) { 0 }

          context 'when vulnerability_states is new_dismissed' do
            let(:vulnerability_states) { %w[new_dismissed] }

            it_behaves_like 'new vulnerability_states', ['new_dismissed']

            it_behaves_like 'sets approvals_required to 0'
          end

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
          end

          context 'when vulnerability_states is new_needs_triage' do
            let(:vulnerability_states) { %w[new_needs_triage] }

            it_behaves_like 'new vulnerability_states', ['new_needs_triage']

            it_behaves_like 'sets approvals_required to 0'
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
        end

        context 'when the approval rules had approvals removed' do
          let_it_be(:approval_project_rule) do
            create(:approval_project_rule, :scan_finding, project: project, approvals_required: 2)
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
              scan_result_policy_id: create(:scan_result_policy_read).id
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

        let(:vulnerability_states) { %w[detected] }

        context 'when vulnerability_states has newly_detected' do
          let(:vulnerability_states) { %w[detected newly_detected] }

          it_behaves_like 'sets approvals_required to 0'

          it_behaves_like 'triggers policy bot comment', :scan_finding, false
        end

        context 'when vulnerability_states are empty array' do
          let(:vulnerability_states) { [] }

          it_behaves_like 'sets approvals_required to 0'

          context 'when security_policies_sync_preexisting_state is disabled' do
            before do
              stub_feature_flags(security_policies_sync_preexisting_state: false)
            end

            it_behaves_like 'sets approvals_required to 0'
            it_behaves_like 'triggers policy bot comment', :scan_finding, false
          end
        end

        context 'when vulnerability_states has new_needs_triage' do
          let(:vulnerability_states) { %w[detected new_needs_triage] }

          it_behaves_like 'sets approvals_required to 0'

          it_behaves_like 'triggers policy bot comment', :scan_finding, false
        end

        context 'when vulnerability_states has new_dismissed' do
          let(:vulnerability_states) { %w[detected new_dismissed] }

          it_behaves_like 'sets approvals_required to 0'

          it_behaves_like 'triggers policy bot comment', :scan_finding, false
        end

        context 'when vulnerability_states has new_needs_triage and new_dismissed' do
          let(:vulnerability_states) { %w[detected new_needs_triage new_dismissed] }

          it_behaves_like 'sets approvals_required to 0'

          it_behaves_like 'triggers policy bot comment', :scan_finding, false
        end

        context 'when vulnerabilities count exceeds the allowed limit' do
          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'does not trigger policy bot comment'

          context 'when security_policies_sync_preexisting_state is disabled' do
            before do
              stub_feature_flags(security_policies_sync_preexisting_state: false)
            end

            it_behaves_like 'does not update approvals_required'
            it_behaves_like 'triggers policy bot comment', :scan_finding, true
          end
        end

        context 'when vulnerabilities count does not exceed the allowed limit' do
          let(:vulnerabilities_allowed) { 6 }

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'does not trigger policy bot comment'

          context 'when security_policies_sync_preexisting_state is disabled' do
            before do
              stub_feature_flags(security_policies_sync_preexisting_state: false)
            end

            it_behaves_like 'sets approvals_required to 0'
            it_behaves_like 'triggers policy bot comment', :scan_finding, false
          end
        end
      end

      context 'when target pipeline is nil' do
        let_it_be(:merge_request) do
          create(:merge_request, source_branch: 'feature', target_branch: 'target-branch')
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', :scan_finding, true

        context 'when security_policies_sync_preexisting_state is disabled' do
          before do
            stub_feature_flags(security_policies_sync_preexisting_state: false)
          end

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'triggers policy bot comment', :scan_finding, true
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
        create_list(:security_finding, 5, scan: related_pipeline_scan, severity: 'high') do |finding, i|
          finding.update_column(:uuid, related_uuids[i])
        end
      end

      let_it_be(:related_target_scan) do
        create(:security_scan, :succeeded,
          project: project,
          pipeline: related_target_pipeline,
          scan_type: 'dependency_scanning'
        )
      end

      before do
        create_list(:security_finding, 5, scan: related_target_scan, severity: 'high') do |finding, i|
          finding.update_column(:uuid, related_uuids[i])
        end

        create_list(:vulnerabilities_finding, 5, project: project) do |finding, i|
          vulnerability = create(:vulnerability, project: project)
          finding.update_columns(uuid: related_uuids[i], vulnerability_id: vulnerability.id)
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
      let_it_be(:policy) { create(:scan_result_policy_read, vulnerability_attributes: { fix_available: true }) }
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
end
