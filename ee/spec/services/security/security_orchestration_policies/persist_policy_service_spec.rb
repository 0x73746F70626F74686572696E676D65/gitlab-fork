# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PersistPolicyService, '#execute', feature_category: :security_policy_management do
  let_it_be_with_reload(:policy_configuration) { create(:security_orchestration_policy_configuration) }

  def persist!(policies)
    described_class
      .new(policy_configuration: policy_configuration, policies: policies, policy_type: policy_type)
      .execute
  end

  shared_examples 'succeeds' do
    specify do
      expect(persist).to include(status: :success)
    end
  end

  shared_examples "persists attributes" do
    before do
      persist
    end

    subject(:persisted_records) { relation }

    include_examples 'succeeds'

    specify do
      expect(persisted_records.size).to be(expected_attributes.size)
    end

    specify do
      persisted_records.each_with_index do |persisted_record, index|
        expect(persisted_record).to have_attributes(expected_attributes[index])
      end
    end
  end

  subject(:persist) { persist!(policies) }

  describe "approval policies" do
    let(:policy_type) { :approval_policy }

    let(:scan_finding_policy) do
      build(:scan_result_policy, :with_approval_settings, :with_policy_scope)
    end

    let(:license_finding_policy) do
      build(:scan_result_policy, :license_finding, :with_approval_settings)
    end

    let(:any_merge_request_policy) do
      build(:scan_result_policy, :any_merge_request, :with_policy_scope)
    end

    let(:policies) do
      [scan_finding_policy, license_finding_policy, any_merge_request_policy]
    end

    context 'without pre-existing policies' do
      include_examples 'succeeds'

      it 'creates policies' do
        expect { persist }.to change { policy_configuration.security_policies.reload.type_approval_policy.count }.by(3)
      end

      it 'creates policy rules' do
        expect do
          persist
        end.to change { Security::ApprovalPolicyRule.type_scan_finding.count }.by(1)
                 .and change { Security::ApprovalPolicyRule.type_license_finding.count }.by(1)
                        .and change { Security::ApprovalPolicyRule.type_any_merge_request.count }.by(1)
      end

      describe 'rule indexes' do
        subject { Security::ApprovalPolicyRule.type_scan_finding.order(rule_index: :asc).pluck(:rule_index) }

        before do
          scan_finding_policy[:rules] *= 2

          persist
        end

        include_examples 'succeeds'

        it { is_expected.to eq([0, 1]) }
      end

      describe 'policy types' do
        subject { Security::ApprovalPolicyRule.pluck(:type) }

        before do
          persist
        end

        include_examples 'succeeds'

        it { is_expected.to contain_exactly("scan_finding", "license_finding", "any_merge_request") }
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'errors' do
          expect(persist).to include(status: :error, message: msg)
        end
      end

      describe 'persisted attributes' do
        describe 'policies' do
          include_examples 'persists attributes' do
            let(:relation) { Security::Policy.type_approval_policy.order(policy_index: :asc) }

            let(:expected_attributes) do
              [
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 0,
                  name: scan_finding_policy[:name],
                  type: 'approval_policy',
                  description: scan_finding_policy[:description],
                  checksum: Security::Policy.checksum(scan_finding_policy),
                  enabled: true,
                  actions: scan_finding_policy[:actions].map(&:stringify_keys),
                  approval_settings: scan_finding_policy[:approval_settings].stringify_keys,
                  scope: scan_finding_policy[:policy_scope].deep_stringify_keys
                },
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 1,
                  name: license_finding_policy[:name],
                  type: 'approval_policy',
                  description: license_finding_policy[:description],
                  checksum: Security::Policy.checksum(license_finding_policy),
                  enabled: true,
                  actions: license_finding_policy[:actions].map(&:stringify_keys),
                  approval_settings: license_finding_policy[:approval_settings].stringify_keys,
                  scope: {}
                },
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 2,
                  name: any_merge_request_policy[:name],
                  type: 'approval_policy',
                  description: any_merge_request_policy[:description],
                  checksum: Security::Policy.checksum(any_merge_request_policy),
                  enabled: true,
                  actions: any_merge_request_policy[:actions].map(&:stringify_keys),
                  approval_settings: {},
                  scope: any_merge_request_policy[:policy_scope].deep_stringify_keys
                }
              ]
            end
          end
        end

        describe 'rules' do
          include_examples 'persists attributes' do
            let(:relation) { Security::ApprovalPolicyRule.type_scan_finding }
            let(:expected_attributes) do
              [{
                security_policy_id: policy_configuration.security_policies.first.id,
                type: 'scan_finding',
                rule_index: 0,
                content: scan_finding_policy[:rules].first.except(:type).stringify_keys
              }]
            end
          end
        end
      end
    end

    context 'with pre-existing policies' do
      let(:pre_existing_policies) { [scan_finding_policy, license_finding_policy] }

      before do
        persist!(pre_existing_policies)
      end

      context 'without policy changes' do
        let(:policies) { pre_existing_policies }

        include_examples 'succeeds'

        it 'does not create or delete policies' do
          expect do
            persist
          end.to not_change { Security::Policy.count }
        end

        it 'does not recreate existing policy rules' do
          expect do
            persist
          end.to not_change { Security::ApprovalPolicyRule.type_scan_finding.pluck(:id) }
                   .and not_change { Security::ApprovalPolicyRule.type_license_finding.pluck(:id) }
                          .and not_change { Security::ApprovalPolicyRule.type_any_merge_request.pluck(:id) }.from([])
        end
      end

      context 'with added policies' do
        let(:policies) { pre_existing_policies << any_merge_request_policy }

        include_examples 'succeeds'

        it 'creates policies' do
          expect do
            persist
          end.to change { Security::Policy.count }.by(1)
                   .and change { Security::ApprovalPolicyRule.pluck(:type) }
                          .from(contain_exactly("scan_finding", "license_finding"))
                          .to(contain_exactly("scan_finding", "license_finding", "any_merge_request"))
        end

        it 'creates new policy rules' do
          expect do
            persist
          end.to not_change { Security::ApprovalPolicyRule.type_scan_finding.pluck(:id) }
                   .and not_change { Security::ApprovalPolicyRule.type_license_finding.pluck(:id) }
                          .and change { Security::ApprovalPolicyRule.type_any_merge_request.count }.by(1)
        end
      end

      context 'with removed policies' do
        let(:policies) { pre_existing_policies - [scan_finding_policy] }

        include_examples 'succeeds'

        it 'deletes policies' do
          expect do
            persist
          end.to change { Security::Policy.count }.by(-1)
                   .and change { Security::ApprovalPolicyRule.pluck(:type) }
                          .from(contain_exactly("scan_finding", "license_finding"))
                          .to(contain_exactly("license_finding"))
        end

        it 'deletes policy rules' do
          expect do
            persist
          end.to change { Security::ApprovalPolicyRule.type_scan_finding.count }.by(-1)
                   .and not_change { Security::ApprovalPolicyRule.type_license_finding.pluck(:id) }
                          .and not_change { Security::ApprovalPolicyRule.type_any_merge_request.pluck(:id) }.from([])
        end
      end

      context 'with updated policy order' do
        let(:policies) { pre_existing_policies.reverse }

        include_examples 'succeeds'

        it 'does not create or delete policies' do
          expect do
            persist
          end.to not_change { Security::Policy.count }.from(2)
                   .and not_change { Security::Policy.pluck(:id).to_set }
        end

        it 'does not recreate existing policy rules' do
          expect do
            persist
          end.to not_change { Security::ApprovalPolicyRule.type_scan_finding.pluck(:id) }
                   .and not_change { Security::ApprovalPolicyRule.type_license_finding.pluck(:id) }
                          .and not_change { Security::ApprovalPolicyRule.type_any_merge_request.pluck(:id) }.from([])
        end

        it 'updates policy indexes' do
          expect do
            persist
          end.to change {
            policy_configuration
              .security_policies
              .order(policy_index: :asc)
              .flat_map(&:approval_policy_rules)
              .flat_map(&:type)
          }
                   .from(%w[scan_finding license_finding])
                   .to(%w[license_finding scan_finding])
        end
      end

      context 'when policy rules decrease' do
        let(:default_rule) { { type: 'any_merge_request', branch_type: 'default', commits: 'any' } }
        let(:protected_rule) { { type: 'any_merge_request', branch_type: 'protected', commits: 'any' } }

        let(:policy_before) { build(:scan_result_policy, rules: [default_rule, protected_rule]) }
        let(:policy_after) { build(:scan_result_policy, rules: [protected_rule]) }

        let(:pre_existing_policies) { [policy_before] }
        let(:policies) { [policy_after] }

        include_examples 'succeeds'

        it 'deletes dangling policy rules' do
          expect do
            persist
          end.to change {
            policy_configuration
              .security_policies
              .order(policy_index: :asc)
              .flat_map(&:approval_policy_rules)
              .flat_map { |rule| rule.content["branch_type"] }
          }
                   .from(%w[default protected])
                   .to(%w[protected])
        end
      end
    end
  end

  describe "scan execution policies" do
    let(:policy_type) { :scan_execution_policy }

    let(:pipeline_policy) do
      build(:scan_execution_policy, :with_policy_scope)
    end

    let(:schedule_policy) do
      build(:scan_execution_policy, :with_schedule, :with_policy_scope)
    end

    let(:policies) do
      [pipeline_policy, schedule_policy]
    end

    context 'without pre-existing policies' do
      include_examples 'succeeds'

      it 'creates policies' do
        expect { persist }.to change {
          policy_configuration.security_policies.reload.type_scan_execution_policy.count
        }.by(2)
      end

      it 'creates policy rules' do
        expect do
          persist
        end.to change { Security::ScanExecutionPolicyRule.type_pipeline.count }.by(1)
                 .and change { Security::ScanExecutionPolicyRule.type_schedule.count }.by(1)
      end

      describe 'rule indexes' do
        subject { Security::ScanExecutionPolicyRule.type_pipeline.order(rule_index: :asc).pluck(:rule_index) }

        before do
          pipeline_policy[:rules] *= 2

          persist
        end

        include_examples 'succeeds'

        it { is_expected.to eq([0, 1]) }
      end

      describe 'policy types' do
        subject { Security::ScanExecutionPolicyRule.pluck(:type) }

        before do
          persist
        end

        include_examples 'succeeds'

        it { is_expected.to contain_exactly("pipeline", "schedule") }
      end

      context 'on exception' do
        let(:msg) { "foobar" }

        before do
          allow(ApplicationRecord).to receive(:transaction).and_raise(StandardError, msg)
        end

        it 'errors' do
          expect(persist).to include(status: :error, message: msg)
        end
      end

      describe 'persisted attributes' do
        describe 'policies' do
          include_examples 'persists attributes' do
            let(:relation) { Security::Policy.type_scan_execution_policy.order(policy_index: :asc) }
            let(:expected_attributes) do
              [
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 0,
                  name: pipeline_policy[:name],
                  type: 'scan_execution_policy',
                  description: pipeline_policy[:description],
                  checksum: Security::Policy.checksum(pipeline_policy),
                  enabled: true,
                  scope: pipeline_policy[:policy_scope].deep_stringify_keys,
                  actions: pipeline_policy[:actions].map(&:stringify_keys)
                },
                {
                  security_orchestration_policy_configuration_id: policy_configuration.id,
                  policy_index: 1,
                  name: schedule_policy[:name],
                  type: 'scan_execution_policy',
                  description: schedule_policy[:description],
                  checksum: Security::Policy.checksum(schedule_policy),
                  enabled: true,
                  scope: schedule_policy[:policy_scope].deep_stringify_keys,
                  actions: schedule_policy[:actions].map(&:stringify_keys)
                }
              ]
            end
          end
        end

        describe 'rules' do
          include_examples 'persists attributes' do
            let(:relation) { Security::ScanExecutionPolicyRule.type_pipeline }

            let(:expected_attributes) do
              [{
                security_policy_id: policy_configuration.security_policies.first.id,
                type: 'pipeline',
                rule_index: 0,
                content: pipeline_policy[:rules].first.except(:type).stringify_keys
              }]
            end
          end
        end
      end
    end
  end

  describe "successive calls with differing policy types" do
    let(:approval_policy) { build(:scan_result_policy) }
    let(:scan_execution_policy) { build(:scan_execution_policy) }

    subject(:execute) do
      described_class
        .new(policy_configuration: policy_configuration,
          policies: [approval_policy],
          policy_type: :approval_policy)
        .execute

      described_class
        .new(policy_configuration: policy_configuration,
          policies: [scan_execution_policy],
          policy_type: :scan_execution_policy)
        .execute
    end

    specify do
      expect { execute }.to change { policy_configuration.security_policies.count }.by(2)
    end
  end

  context "with unrecognized policy type" do
    let(:policies) { [] }
    let(:policy_type) { :foobar }

    it 'errors' do
      expect { persist }.to raise_error(ArgumentError, "unrecognized policy_type")
    end
  end
end
