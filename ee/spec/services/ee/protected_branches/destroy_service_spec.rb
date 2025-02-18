# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranches::DestroyService, feature_category: :compliance_management do
  let(:project) { protected_branch.project }
  let(:protected_branch) { create(:protected_branch) }
  let(:branch_name) { protected_branch.name }
  let(:user) { project.first_owner }

  let!(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  describe '#execute' do
    subject(:service) { described_class.new(project, user) }

    it 'adds a security audit event entry' do
      expect { service.execute(protected_branch) }.to change(::AuditEvent, :count).by(1)
    end

    context 'when destroy succeeds but cache refresh fails' do
      let(:bad_cache) { instance_double('ProtectedBranches::CacheService') }
      let(:exception) { RuntimeError }

      before do
        expect(ProtectedBranches::CacheService).to receive(:new).with(project, user, {}).and_return(bad_cache)
        expect(bad_cache).to receive(:refresh).and_raise(exception)
      end

      it "adds a security audit event entry" do
        expect { service.execute(protected_branch) }.to change(::AuditEvent, :count).by(1)
      end

      it "tracks the exception" do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(exception).once

        service.execute(protected_branch)
      end
    end

    context 'when security_orchestration_policies is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
        allow(project).to receive(:all_security_orchestration_policy_configurations)
                            .and_return([security_orchestration_policy_configuration])
      end

      it 'does not sync scan_finding_approval_rules' do
        expect(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesService).not_to receive(:new)
        expect(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService).not_to receive(:new)

        service.execute(protected_branch)
      end
    end

    context 'when security_orchestration_policies is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
        allow(project).to receive(:all_security_orchestration_policy_configurations)
                            .and_return([security_orchestration_policy_configuration])
      end

      it 'syncs scan_finding_approval_rules' do
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService,
          security_orchestration_policy_configuration
        ) do |sync_service|
          expect(sync_service).to receive(:execute).with(project.id,
            { delay: ::EE::ProtectedBranches::BaseService::SYNC_SERVICE_DELAY_INTERVAL })
        end

        service.execute(protected_branch)
      end

      context 'with blocking scan result policy' do
        let_it_be(:project) { create(:project, :repository) }
        let(:protected_branch) { create(:protected_branch, project: project, name: 'master') }

        include_context 'with scan result policy blocking protected branches' do
          let(:branch_name) { protected_branch.name }
          let(:policy_configuration) { security_orchestration_policy_configuration }

          it 'blocks unprotecting branches' do
            expect { service.execute(protected_branch) }.to raise_error(Gitlab::Access::AccessDeniedError)
          end
        end
      end

      context 'with group-level protected branch' do
        let(:group) { create(:group) }
        let(:protected_branch) { create(:protected_branch, project_id: nil, namespace_id: group.id, name: 'master') }

        subject(:service) { described_class.new(group, user) }

        include_context 'with scan result policy' do
          let(:security_orchestration_policy_configuration) do
            create(
              :security_orchestration_policy_configuration,
              :namespace,
              security_policy_management_project: policy_project,
              namespace: group)
          end

          let(:policy_configuration) { security_orchestration_policy_configuration }
          let(:user) { create(:user) }
          let(:branch_name) { protected_branch.name }
          let(:scan_result_policies) do
            [build(:scan_result_policy, approval_settings: { block_group_branch_modification: true })]
          end

          before do
            group.add_owner(user)
          end

          it 'blocks unprotecting branches' do
            expect { service.execute(protected_branch) }.to raise_error(Gitlab::Access::AccessDeniedError)
          end

          context 'with feature disabled' do
            before do
              stub_feature_flags(scan_result_policy_block_group_branch_modification: false)
            end

            it 'does not block unprotecting branches' do
              expect { service.execute(protected_branch) }.not_to raise_error
            end
          end
        end
      end
    end

    context 'when destroy fails' do
      before do
        expect(protected_branch).to receive(:destroy).and_return(false)
      end

      it "doesn't add a security audit event entry" do
        expect { service.execute(protected_branch) }.not_to change(::AuditEvent, :count)
      end
    end
  end
end
