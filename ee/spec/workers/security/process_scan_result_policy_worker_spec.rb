# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProcessScanResultPolicyWorker, feature_category: :security_policy_management do
  let_it_be(:configuration, refind: true) { create(:security_orchestration_policy_configuration, configured_at: nil) }

  let(:active_policies) do
    {
      scan_execution_policy: [],
      scan_result_policy:
      [
        {
          name: 'CS critical policy',
          description: 'This policy with CS for critical policy',
          enabled: true,
          rules: [
            { type: 'scan_finding', branches: %w[production], vulnerabilities_allowed: 0,
              severity_levels: %w[critical], scanners: %w[container_scanning],
              vulnerability_states: %w[newly_detected] }
          ],
          actions: [
            { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }
          ]
        }
      ]
    }
  end

  before do
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(active_policies.to_yaml)
      allow(repository).to receive(:last_commit_for_path)
    end
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    it 'calls three services to general merge request approval rules from the policy YAML' do
      active_policies[:scan_result_policy].each_with_index do |policy, policy_index|
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService,
          project: configuration.project,
          policy_configuration: configuration,
          policy: policy,
          policy_index: policy_index
        ) do |service|
          expect(service).to receive(:execute)
        end
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService,
          project: configuration.project
        ) do |service|
          expect(service).to receive(:execute)
        end
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncOpenMergeRequestsHeadPipelineService,
          project: configuration.project
        ) do |service|
          expect(service).to receive(:execute)
        end
      end

      worker.perform(configuration.project_id, configuration.id)
    end

    shared_context 'with scan_result_policy_reads' do
      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration)
      end

      let!(:software_license_without_scan_result_policy) do
        create(:software_license_policy, project: project)
      end

      let!(:software_license_with_scan_result_policy) do
        create(:software_license_policy, project: project,
          scan_result_policy_read: scan_result_policy_read)
      end

      it 'deletes software_license_policies associated to the project' do
        worker.perform(project.id, configuration.id)

        software_license_policies = SoftwareLicensePolicy.where(project_id: project.id)
        expect(software_license_policies).to match_array([software_license_without_scan_result_policy])
      end

      it 'does not delete scan_result_policy_reads' do
        worker.perform(project.id, configuration.id)

        expect(scan_result_policy_read.reload.id).to eq(scan_result_policy_read.id)
      end
    end

    context 'when policy is linked to a project level' do
      let_it_be(:project) { configuration.project }

      include_context 'with scan_result_policy_reads'
    end

    context 'when policy is linked to a group level' do
      let_it_be(:project) { create(:project) }
      let_it_be(:configuration) do
        create(:security_orchestration_policy_configuration,
          namespace: project.namespace,
          project: nil,
          configured_at: nil
        )
      end

      include_context 'with scan_result_policy_reads'
    end

    context 'with non existing project' do
      it 'returns prior to triggering any service' do
        expect(Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService).not_to receive(:execute)
        expect(Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService).not_to receive(:execute)
        expect(Security::SecurityOrchestrationPolicies::SyncOpenMergeRequestsHeadPipelineService)
          .not_to receive(:execute)

        worker.perform('invalid_id', configuration.id)
      end
    end

    context 'with non existing configuration' do
      it 'returns prior to triggering any service' do
        expect(Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService).not_to receive(:execute)
        expect(Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService).not_to receive(:execute)
        expect(Security::SecurityOrchestrationPolicies::SyncOpenMergeRequestsHeadPipelineService)
          .not_to receive(:execute)

        worker.perform(configuration.project_id, 'invalid_id')
      end
    end

    context 'when no scan result policies are configured' do
      before do
        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return([].to_yaml)
        end
      end

      it 'returns prior to triggering any service' do
        expect(Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService).not_to receive(:execute)
        expect(Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService).not_to receive(:execute)
        expect(Security::SecurityOrchestrationPolicies::SyncOpenMergeRequestsHeadPipelineService)
          .not_to receive(:execute)

        worker.perform(configuration.project_id, 'invalid_id')
      end
    end

    describe "lease acquisition" do
      let(:lease_key) { described_class.lease_key(configuration.project, configuration) }

      subject { worker.perform(configuration.project_id, configuration.id) }

      it "obtains a #{described_class::LEASE_TTL} second exclusive lease" do
        expect(Gitlab::ExclusiveLeaseHelpers::SleepingLock)
          .to receive(:new)
                .with(lease_key, hash_including(timeout: described_class::LEASE_TTL))
                .and_call_original

        subject
      end

      context 'when lease is not obtained' do
        before do
          stub_const('Security::ProcessScanResultPolicyWorker::LEASE_RETRY_BASE', 0)
          Gitlab::ExclusiveLease.new(lease_key, timeout: described_class::LEASE_TTL).try_obtain
        end

        it 'does not invoke Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService' do
          allow_next_instance_of(Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService) do |service|
            expect(service).not_to receive(:execute)
          end

          expect { subject }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
        end
      end

      describe "#lease_sleep_sec" do
        let(:retry_count) { Gitlab::ExclusiveLeaseHelpers::SleepingLock::DEFAULT_ATTEMPTS }

        subject do
          (0..retry_count).to_a.map do |attempt|
            worker.lease_sleep_sec(attempt).round(2)
          end
        end

        it "uses exponential backoff" do
          expect(subject).to eq [0.1, 0.13, 0.17, 0.22, 0.29, 0.37, 0.48, 0.63, 0.82, 1.06, 1.38]
        end

        it "retries for at least 5 seconds" do
          expect(subject.sum).to be > 5
        end
      end
    end
  end
end
