# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService, "#execute", feature_category: :security_policy_management do
  include RepoHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:policy_project) { create(:project, :repository) }
  let_it_be(:group) { build(:group) }
  let_it_be(:policy_config) do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      security_policy_management_project: policy_project,
      namespace: group)
  end

  let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [], scan_result_policy: policies) }
  let(:policies) { [policy] }
  let(:policy) { build(:scan_result_policy, approval_settings: approval_settings) }
  let(:approval_settings) do
    { block_branch_modification: block_branch_modification,
      block_group_branch_modification: block_group_branch_modification }.compact
  end

  before do
    allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |repo|
      allow(repo).to receive(:policy_blob)
                       .and_return(policy_yaml)
    end
  end

  subject(:execute) do
    described_class.new(group: group).execute
  end

  where(:block_branch_modification, :block_group_branch_modification, :expectation) do
    true | nil   | true
    true | true  | true
    true | false | false
    nil  | nil   | false
    nil  | true  | true
    nil  | false | false

    true | { enabled: true }  | true
    true | { enabled: false } | false
    nil  | { enabled: true }  | true
    nil  | { enabled: false } | false

    true  | { enabled: true, exceptions: [lazy { group.full_path }] }  | false
    true  | { enabled: false, exceptions: [lazy { group.full_path }] } | false
    false | { enabled: true, exceptions: [lazy { group.full_path }] }  | false
    false | { enabled: false, exceptions: [lazy { group.full_path }] } | false

    true  | { enabled: true, exceptions: [lazy { group.full_path.reverse }] }  | true
    true  | { enabled: false, exceptions: [lazy { group.full_path.reverse }] } | false
    false | { enabled: true, exceptions: [lazy { group.full_path.reverse }] }  | true
    false | { enabled: false, exceptions: [lazy { group.full_path.reverse }] } | false
  end

  with_them do
    it { is_expected.to be(expectation) }
  end

  context 'with feature disabled' do
    before do
      stub_feature_flags(scan_result_policy_block_group_branch_modification: false)
    end

    let(:block_branch_modification) { true }
    let(:block_group_branch_modification) { true }

    it { is_expected.to be(false) }
  end

  context 'without approval_settings' do
    let(:approval_settings) { nil }

    it { is_expected.to be(false) }
  end

  context 'with conflicting settings' do
    let(:policies) do
      [build(:scan_result_policy, approval_settings: { block_group_branch_modification: true }),
        build(:scan_result_policy, approval_settings: { block_group_branch_modification: false })]
    end

    it { is_expected.to be(true) }
  end
end
