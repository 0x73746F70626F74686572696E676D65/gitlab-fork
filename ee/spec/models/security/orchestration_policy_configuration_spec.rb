# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::OrchestrationPolicyConfiguration, feature_category: :security_policy_management do
  let_it_be(:security_policy_management_project) { create(:project, :repository) }

  let(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: security_policy_management_project)
  end

  let(:default_branch) { security_policy_management_project.default_branch }
  let(:repository) { instance_double(Repository, root_ref: 'master', empty?: false) }
  let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy, name: 'Run DAST in every pipeline')], scan_result_policy: [build(:scan_result_policy, name: 'Containe security critical severities')]) }

  before do
    allow(security_policy_management_project).to receive(:repository).and_return(repository)
    allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
  end

  shared_examples 'captures git errors' do |repository_method|
    context 'when repository is unavailable' do
      before do
        allow(repository).to receive(repository_method).and_raise(GRPC::BadStatus, GRPC::Core::StatusCodes::DEADLINE_EXCEEDED)
      end

      it { is_expected.to be_nil }

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(Gitlab::Git::CommandTimedOut, action: repository_method, security_orchestration_policy_configuration_id: security_orchestration_policy_configuration.id)

        subject
      end
    end
  end

  shared_examples 'does not deletes merge request approval rules of merged MR' do
    context 'with approval rules for merged MRs' do
      let(:merge_request_to_be_merged) do
        create(:merge_request,
          target_project: project,
          source_project: project,
          source_branch: 'feature-1')
      end

      let!(:approval_merge_rule_merged_mr) do
        create(:report_approver_rule,
          :scan_finding,
          merge_request: merge_request_to_be_merged,
          security_orchestration_policy_configuration_id: security_orchestration_policy_configuration_id)
      end

      before do
        merge_request_to_be_merged.mark_as_merged!
      end

      it 'does not deletes merge request approval rules of merged MRs' do
        subject
        expect(ApprovalMergeRequestRule.find(approval_merge_rule_merged_mr.id)).to be_present
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).inverse_of(:security_orchestration_policy_configuration) }
    it { is_expected.to belong_to(:namespace).inverse_of(:security_orchestration_policy_configuration) }
    it { is_expected.to belong_to(:security_policy_management_project).class_name('Project') }
    it { is_expected.to have_many(:rule_schedules).class_name('Security::OrchestrationPolicyRuleSchedule').inverse_of(:security_orchestration_policy_configuration) }
    it { is_expected.to have_many(:compliance_framework_security_policies).class_name('ComplianceManagement::ComplianceFramework::SecurityPolicy') }
    it { is_expected.to have_many(:security_policies).class_name('Security::Policy') }
  end

  describe 'validations' do
    subject { create(:security_orchestration_policy_configuration) }

    context 'when created for project' do
      it { is_expected.not_to validate_presence_of(:namespace) }
      it { is_expected.to validate_presence_of(:project) }
      it { is_expected.to validate_uniqueness_of(:project) }
    end

    context 'when created for namespace' do
      subject { create(:security_orchestration_policy_configuration, :namespace) }

      it { is_expected.not_to validate_presence_of(:project) }
      it { is_expected.to validate_presence_of(:namespace) }
      it { is_expected.to validate_uniqueness_of(:namespace) }
    end

    it { is_expected.to validate_presence_of(:security_policy_management_project) }
  end

  describe '.for_project' do
    let_it_be(:security_orchestration_policy_configuration_1) { create(:security_orchestration_policy_configuration) }
    let_it_be(:security_orchestration_policy_configuration_2) { create(:security_orchestration_policy_configuration) }
    let_it_be(:security_orchestration_policy_configuration_3) { create(:security_orchestration_policy_configuration) }

    subject { described_class.for_project([security_orchestration_policy_configuration_2.project, security_orchestration_policy_configuration_3.project]) }

    it 'returns configuration for given projects' do
      is_expected.to contain_exactly(security_orchestration_policy_configuration_2, security_orchestration_policy_configuration_3)
    end
  end

  describe '.for_namespace' do
    let_it_be(:security_orchestration_policy_configuration_1) { create(:security_orchestration_policy_configuration, :namespace) }
    let_it_be(:security_orchestration_policy_configuration_2) { create(:security_orchestration_policy_configuration, :namespace) }
    let_it_be(:security_orchestration_policy_configuration_3) { create(:security_orchestration_policy_configuration, :namespace) }

    subject { described_class.for_namespace([security_orchestration_policy_configuration_2.namespace, security_orchestration_policy_configuration_3.namespace]) }

    it 'returns configuration for given namespaces' do
      is_expected.to contain_exactly(security_orchestration_policy_configuration_2, security_orchestration_policy_configuration_3)
    end
  end

  describe '.for_management_project' do
    let_it_be(:security_orchestration_policy_configuration_1) { create(:security_orchestration_policy_configuration, security_policy_management_project: security_policy_management_project) }
    let_it_be(:security_orchestration_policy_configuration_2) { create(:security_orchestration_policy_configuration, security_policy_management_project: security_policy_management_project) }
    let_it_be(:security_orchestration_policy_configuration_3) { create(:security_orchestration_policy_configuration) }

    subject { described_class.for_management_project(security_policy_management_project) }

    it 'returns configuration for given the policy management project' do
      is_expected.to contain_exactly(security_orchestration_policy_configuration_1, security_orchestration_policy_configuration_2)
    end
  end

  describe '.with_outdated_configuration' do
    let!(:security_orchestration_policy_configuration_1) { create(:security_orchestration_policy_configuration, configured_at: nil) }
    let!(:security_orchestration_policy_configuration_2) { create(:security_orchestration_policy_configuration, configured_at: Time.zone.now - 1.hour) }
    let!(:security_orchestration_policy_configuration_3) { create(:security_orchestration_policy_configuration, configured_at: Time.zone.now + 1.hour) }

    subject { described_class.with_outdated_configuration }

    it 'returns configuration with outdated configurations' do
      is_expected.to contain_exactly(security_orchestration_policy_configuration_1, security_orchestration_policy_configuration_2)
    end
  end

  describe '.for_management_project_within_descendants' do
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:subgroup_a) { create(:group, parent: top_level_group) }
    let_it_be(:subgroup_b) { create(:group, parent: subgroup_a) }

    let_it_be(:top_level_group_project) { create(:project, group: top_level_group) }
    let_it_be(:subgroup_project) { create(:project, group: subgroup_a) }

    let!(:policy_configuration_a) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: top_level_group.id)
    end

    let!(:policy_configuration_b) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: subgroup_b.id,
        security_policy_management_project_id: policy_project_id)
    end

    let!(:policy_configuration_c) do
      create(
        :security_orchestration_policy_configuration,
        project: top_level_group_project,
        security_policy_management_project_id: policy_project_id)
    end

    let!(:policy_configuration_d) do
      create(
        :security_orchestration_policy_configuration,
        project: subgroup_project,
        security_policy_management_project_id: policy_project_id)
    end

    let!(:other_policy_configuration) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: subgroup_a.id)
    end

    let(:policy_project_id) { policy_configuration_a.security_policy_management_project_id }

    subject { described_class.for_management_project_within_descendants(policy_project_id, top_level_group) }

    it { is_expected.to contain_exactly(policy_configuration_b, policy_configuration_c, policy_configuration_d) }
  end

  describe '.policy_management_project?' do
    before do
      create(:security_orchestration_policy_configuration, security_policy_management_project: security_policy_management_project)
    end

    it 'returns true when security_policy_management_project with id exists' do
      expect(described_class.policy_management_project?(security_policy_management_project.id)).to be_truthy
    end

    it 'returns false when security_policy_management_project with id does not exist' do
      expect(described_class.policy_management_project?(non_existing_record_id)).to be_falsey
    end
  end

  describe '.valid_scan_type?' do
    it 'returns true when scan type is valid' do
      expect(Security::ScanExecutionPolicy.valid_scan_type?('secret_detection')).to be_truthy
    end

    it 'returns false when scan type is invalid' do
      expect(Security::ScanExecutionPolicy.valid_scan_type?('invalid')).to be_falsey
    end
  end

  describe '#policy_configuration_exists?' do
    subject { security_orchestration_policy_configuration.policy_configuration_exists? }

    context 'when file is missing' do
      let(:policy_yaml) { nil }

      it { is_expected.to eq(false) }
    end

    context 'when policy is present' do
      it { is_expected.to eq(true) }
    end
  end

  describe '#policy_hash' do
    subject { security_orchestration_policy_configuration.policy_hash }

    let(:cache_key) do
      "security_orchestration_policy_configurations:#{security_orchestration_policy_configuration.id}:policy_yaml"
    end

    context 'when policy is present' do
      it { expect(subject.dig(:scan_execution_policy, 0, :name)).to eq('Run DAST in every pipeline') }
    end

    context 'when policy has invalid YAML format' do
      let(:policy_yaml) do
        'cadence: * 1 2 3'
      end

      it { expect(subject).to be_nil }
    end

    context 'when policy is nil' do
      let(:policy_yaml) { nil }

      it { expect(subject).to be_nil }
    end

    it_behaves_like 'captures git errors', :blob_data_at

    context 'with cache enabled' do
      it 'fetches from cache' do
        expect(Rails.cache).to receive(:fetch).with(cache_key, { expires_in: described_class::CACHE_DURATION }).and_call_original

        subject
      end
    end
  end

  describe '#invalidate_policy_yaml_cache' do
    subject { security_orchestration_policy_configuration.invalidate_policy_yaml_cache }

    let(:cache_key) do
      "security_orchestration_policy_configurations:#{security_orchestration_policy_configuration.id}:policy_yaml"
    end

    it 'invalidates cache' do
      expect(Rails.cache).to receive(:delete).with(cache_key).and_call_original

      subject
    end
  end

  describe '#policy_by_type' do
    subject(:policies) { security_orchestration_policy_configuration.policy_by_type(type) }

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
    end

    context 'when policy is present' do
      let(:policy_yaml) do
        build(:orchestration_policy_yaml,
          scan_execution_policy: [build(:scan_execution_policy, name: 'Run DAST in every pipeline')],
          scan_result_policy: [build(:scan_result_policy, name: 'Require approvals for scan result policy')],
          approval_policy: [build(:approval_policy, name: 'Require approvals for approval policy')],
          pipeline_execution_policy: [build(:pipeline_execution_policy, name: 'Run custom pipeline configuration')],
          ci_component_sources_policy: [build(:ci_component_sources_policy, name: 'Allow publishing from auth sources')]
        )
      end

      context 'when type is a string' do
        let(:type) { :scan_execution_policy }

        it 'retrieves policy by type' do
          expect(policies.first[:name]).to eq('Run DAST in every pipeline')
        end
      end

      context 'when type is a string for ci_component_sources_policy' do
        let(:type) { :ci_component_sources_policy }

        it 'retrieves policy by type' do
          expect(policies.first[:name]).to eq('Allow publishing from auth sources')
        end
      end

      context 'when type is a string for pipeline execution' do
        let(:type) { :pipeline_execution_policy }

        it 'retrieves policy by type' do
          expect(policies.first[:name]).to eq('Run custom pipeline configuration')
        end
      end

      context 'when type is an array' do
        let(:type) { %i[scan_result_policy approval_policy] }

        it 'retrieves all applicable policies by type' do
          expect(policies.size).to eq(2)
          expect(policies.pluck(:name))
            .to contain_exactly 'Require approvals for scan result policy', 'Require approvals for approval policy'
        end
      end
    end

    context 'when type does not match any existing policy' do
      let(:type) { :scan_result_policy }
      let(:policy_yaml) do
        build(:orchestration_policy_yaml,
          scan_execution_policy: [build(:scan_execution_policy, name: 'Run DAST in every pipeline')])
      end

      it 'returns an empty array' do
        expect(policies).to eq([])
      end
    end

    context 'when policy is nil' do
      let(:policy_yaml) { nil }

      context 'when type is a string' do
        let(:type) { :scan_execution_policy }

        it 'returns an empty array' do
          expect(policies).to eq([])
        end
      end

      context 'when type is an array' do
        let(:type) { %i[scan_result_policy approval_policy] }

        it 'returns an empty array' do
          expect(policies).to eq([])
        end
      end
    end
  end

  describe '#policy_configuration_valid?' do
    subject { security_orchestration_policy_configuration.policy_configuration_valid? }

    context 'when file is invalid' do
      let(:policy_yaml) do
        build(:orchestration_policy_yaml, scan_execution_policy:
        [build(:scan_execution_policy, rules: [{ type: 'pipeline', branches: 'production' }])])
      end

      it { is_expected.to eq(false) }
    end

    context 'when file has invalid name' do
      let(:invalid_name) { 'a' * 256 }
      let(:policy_yaml) do
        build(:orchestration_policy_yaml, scan_execution_policy:
        [build(:scan_execution_policy, name: invalid_name)])
      end

      it { is_expected.to be false }
    end

    context 'when file is valid' do
      it { is_expected.to eq(true) }

      context 'with license_scanning policy' do
        let(:policy_yaml) do
          build(
            :orchestration_policy_yaml,
            scan_execution_policy: [],
            scan_result_policy: [build(:scan_result_policy, :license_finding)]
          )
        end

        it { is_expected.to eq(true) }
      end
    end

    context 'when policy is passed as argument' do
      let_it_be(:policy_yaml) { nil }
      let_it_be(:policy) { { scan_execution_policy: [build(:scan_execution_policy)] } }

      context 'when scan type is secret_detection' do
        it 'returns false if extra fields are present' do
          invalid_policy = policy.deep_dup
          invalid_policy[:scan_execution_policy][0][:actions][0][:scan] = 'secret_detection'
          invalid_policy[:scan_execution_policy][0][:actions][0][:variables] = { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false' }
          invalid_policy[:scan_execution_policy][0][:actions][0][:tags] = %w[linux]

          expect(security_orchestration_policy_configuration.policy_configuration_valid?(invalid_policy)).to be_falsey
        end

        it 'returns true if extra fields are not present' do
          valid_policy = policy.deep_dup
          valid_policy[:scan_execution_policy][0][:actions][0] = { scan: 'secret_detection' }

          expect(security_orchestration_policy_configuration.policy_configuration_valid?(valid_policy)).to be_truthy
        end
      end

      context 'for schedule policy rule' do
        using RSpec::Parameterized::TableSyntax

        let_it_be(:schedule_policy) { { scan_execution_policy: [build(:scan_execution_policy, :with_schedule)] } }

        subject { security_orchestration_policy_configuration.policy_configuration_valid?(schedule_policy) }

        where(:cadence, :is_valid) do
          "@weekly"           | true
          "@yearly"           | true
          "@annually"         | true
          "@monthly"          | true
          "@weekly"           | true
          "@daily"            | true
          "@midnight"         | true
          "@noon"             | true
          "@hourly"           | true
          "* * * * *"         | true
          "0 0 2 3 *"         | true
          "* * L * *"         | true
          "* * -6 * *"        | true
          "* * -3 * *"        | true
          "* * 12 * *"        | true
          "0 9 -4 * *"        | true
          "0 0 -8 * *"        | true
          "7 10 * * *"        | true
          "00 07 * * *"       | true
          "* * * * tue"       | true
          "* * * * TUE"       | true
          "12 10 0 * *"       | true
          "52 20 * * 2"       | true
          "* * last * *"      | true
          "0 2 last * *"      | true
          "52 9 2-5 * 2"      | true
          "0 0 27 3 1,5"      | true
          "0 0 11 * 3-6"      | true
          "0 0 -7-L * *"      | true
          "0 0 -1,-2 * *"     | true
          "10/30 * * * *"     | true
          "21 37 4,12 * 3"    | true
          "02 07 21 jan *"    | true
          "02 07 21 JAN *"    | true
          "0 1 L * wed-fri"   | true
          "0 1 L * wed-FRI"   | true
          "0 1 L * WED-fri"   | true
          "0 1 L * WED-FRI"   | true
          "0 0 21 4 sat,sun"  | true
          "0 0 21 4 SAT,SUN"  | true
          "10-30/30 * * * *"  | true

          ""                  | false
          "1"                 | false
          "2 3 4"             | false
          "invalid"           | false
          "@WEEKLY"           | false
          "@YEARLY"           | false
          "@ANNUALLY"         | false
          "@MONTHLY"          | false
          "@WEEKLY"           | false
          "@DAILY"            | false
          "@MIDNIGHT"         | false
          "@NOON"             | false
          "@HOURLY"           | false
        end

        with_them do
          before do
            schedule_policy[:scan_execution_policy][0][:rules][0][:cadence] = cadence
          end

          it { is_expected.to eq(is_valid) }
        end
      end
    end

    context 'with scan result policies' do
      let(:policy_name) { 'Contains security critical severities' }
      let(:scan_result_policy) { build(:scan_result_policy, name: policy_name) }
      let(:policy_yaml) { build(:orchestration_policy_yaml, scan_result_policy: [scan_result_policy]) }

      it { is_expected.to eq(true) }

      context 'with various approvers' do
        using RSpec::Parameterized::TableSyntax

        where(:user_approvers, :user_approvers_ids, :group_approvers, :group_approvers_ids, :role_approvers, :is_valid) do
          []           | nil  | nil            | nil | nil | false
          ['username'] | nil  | nil            | nil | nil | true
          nil          | []   | nil            | nil | nil | false
          nil          | [1]  | nil            | nil | nil | true
          nil          | nil  | []             | nil | nil | false
          nil          | nil  | ['group_path'] | nil | nil | true
          nil          | nil  | nil            | []  | nil | false
          nil          | nil  | nil            | [2] | nil | true
          nil          | nil  | nil            | nil | [] | false
          nil          | nil  | nil            | nil | ['developer'] | true
        end

        with_them do
          let(:action) do
            { type: 'require_approval',
              approvals_required: 1,
              user_approvers: user_approvers,
              user_approvers_ids: user_approvers_ids,
              group_approvers: group_approvers,
              group_approvers_ids: group_approvers_ids,
              role_approvers: role_approvers }.compact
          end

          let(:scan_result_policy) { build(:scan_result_policy, name: 'Contains security critical severities', actions: [action]) }

          it { is_expected.to eq(is_valid) }
        end
      end

      context 'with various policy names' do
        using RSpec::Parameterized::TableSyntax

        where(:policy_name, :expected_to_be_valid) do
          ApprovalRuleLike::DEFAULT_NAME_FOR_LICENSE_REPORT                 | false
          ApprovalRuleLike::DEFAULT_NAME_FOR_COVERAGE                       | false
          "New #{ApprovalRuleLike::DEFAULT_NAME_FOR_LICENSE_REPORT}"        | true
          "#{ApprovalRuleLike::DEFAULT_NAME_FOR_COVERAGE} through policies" | true
        end

        with_them do
          it { is_expected.to eq(expected_to_be_valid) }
        end
      end
    end
  end

  describe '#policy_configuration_validation_errors' do
    let(:scan_execution_policy) { nil }
    let(:scan_result_policy) { nil }
    let(:pipeline_execution_policy) { nil }

    let(:policy_yaml) do
      {
        scan_execution_policy: [scan_execution_policy].compact,
        scan_result_policy: [scan_result_policy].compact,
        pipeline_execution_policy: [pipeline_execution_policy].compact
      }
    end

    subject(:errors) do
      security_orchestration_policy_configuration.policy_configuration_validation_errors(policy_yaml)
    end

    context "without policies" do
      let(:policy_yaml) { {} }

      specify do
        expect(errors).to contain_exactly("root is missing required keys: scan_execution_policy",
          "root is missing required keys: scan_result_policy",
          "root is missing required keys: approval_policy",
          "root is missing required keys: pipeline_execution_policy",
          "root is missing required keys: ci_component_source_policy")
      end
    end

    shared_examples "branch_exceptions" do
      let(:valid_exceptions) do
        [
          %w[master develop],
          [{ name: "master", full_path: "foobar" }],
          ["master", { name: "develop", full_path: "foobar" }]
        ]
      end

      specify do
        valid_exceptions.each do |exceptions|
          rule[:branch_exceptions] = exceptions

          expect(errors).not_to include(match("branch_exceptions"))
        end
      end

      context "with empty branch_exceptions" do
        let(:empty_exceptions) do
          [[], [""]]
        end

        specify do
          empty_exceptions.each do |exceptions|
            rule[:branch_exceptions] = exceptions

            expect(errors).to include(match("property '/.*branch_exceptions' is invalid: error_type=minItems"))
          end
        end
      end

      context "with repeated items" do
        specify do
          rule[:branch_exceptions] = %w[master master]

          expect(errors).to include(match(%r{property '/.*branch_exceptions' is invalid: error_type=uniqueItems}))
        end
      end

      context "with invalid branch_exceptions" do
        let(:invalid_exceptions) { [{}, { name: "master" }, { full_path: "foobar" }] }

        specify do
          invalid_exceptions.each do |exceptions|
            rule[:branch_exceptions] = [exceptions]

            expect(errors).to include(match(%r{property '/.*branch_exceptions/0' is missing required keys}))
          end
        end
      end
    end

    shared_examples "policy_scope" do
      context 'with empty object' do
        let(:policy_scope) { {} }

        specify { expect(errors).to be_empty }
      end

      context 'with allowed properties' do
        let(:policy_scope) do
          {
            compliance_frameworks: [
              { id: 1 },
              { id: 2 }
            ],
            projects: {
              including: [
                { id: 1 }
              ],
              excluding: [
                { id: 2 }
              ]
            }
          }
        end

        specify { expect(errors).to be_empty }
      end

      context 'with invalid properties' do
        let(:policy_scope) do
          {
            compliance_frameworks: {},
            projects: [
              { id: 3 }
            ]
          }
        end

        specify { expect(errors).not_to be_empty }
      end
    end

    describe "scan execution policies" do
      let(:scan_execution_policy) { build(:scan_execution_policy, rules: rules, actions: actions, policy_scope: policy_scope) }
      let(:rules) { [rule].compact }
      let(:rule) { nil }
      let(:actions) { [action].compact }
      let(:action) { nil }
      let(:policy_scope) { {} }

      %i[name enabled rules actions].each do |key|
        context "without #{key}" do
          before do
            scan_execution_policy.delete(key)
          end

          specify do
            expect(errors).to contain_exactly("property '/scan_execution_policy/0' is missing required keys: #{key}")
          end
        end
      end

      describe "name" do
        context "when too short" do
          before do
            scan_execution_policy[:name] = ""
          end

          specify do
            expect(errors).to contain_exactly("property '/scan_execution_policy/0/name' is invalid: error_type=minLength")
          end
        end

        context "when too long" do
          before do
            scan_execution_policy[:name] = "a" * 256
          end

          specify do
            expect(errors).to contain_exactly("property '/scan_execution_policy/0/name' is invalid: error_type=maxLength")
          end
        end
      end

      describe "rules" do
        context "with invalid type" do
          let(:rule) { { type: "foobar" } }

          specify do
            expect(errors.count).to be(4)
            expect(errors.last).to match("property '/scan_execution_policy/0/rules/0/type' is not one of")
          end
        end

        context "with schedule type" do
          let(:rule) { { type: "schedule", branches: %w[master], cadence: "5 4 * * *" } }

          specify { expect(errors).to be_empty }

          context "with invalid cadence" do
            before do
              rule[:cadence] = "foobar"
            end

            specify do
              expect(errors.count).to be(1)
              expect(errors.first).to match("property '/scan_execution_policy/0/rules/0/cadence' does not match pattern")
            end
          end
        end

        context "with schedule type and agent" do
          let(:rule) { { type: "schedule", agents: { foo: { namespaces: %w[bar] } }, cadence: "5 4 * * *" } }

          specify { expect(errors).to be_empty }

          context "with invalid agent name" do
            before do
              rule[:agents][:"with spaces"] = rule[:agents].delete(:foo)
            end

            specify do
              expect(errors.count).to be(1)
              expect(errors.first).to match(
                "property '/scan_execution_policy/0/rules/0/agents/with spaces' is invalid: error_type=schema")
            end
          end
        end

        context "with branches" do
          let(:rule) { { type: "pipeline", branches: ["master"] } }

          specify { expect(errors).to be_empty }

          context "with branch_type" do
            before do
              rule[:branch_type] = "all"
            end

            specify do
              expect(errors).to contain_exactly("property '/scan_execution_policy/0/rules/0' is invalid: error_type=oneOf")
            end
          end
        end

        context "with branch_type" do
          let(:rule) { { type: "pipeline", branch_type: "protected" } }

          specify { expect(errors).to be_empty }
        end

        context "with branch_exceptions" do
          let(:rule) { {} }

          it_behaves_like "branch_exceptions"
        end
      end

      describe "actions" do
        let(:action) { { scan: "container_scanning" } }

        specify { expect(errors).to be_empty }

        context "with invalid scan" do
          before do
            action[:scan] = "foobar"
          end

          specify do
            expect(errors.count).to be(1)
            expect(errors.first).to match("property '/scan_execution_policy/0/actions/0/scan' is not one of")
          end
        end

        context "with DAST scan" do
          let(:action) { { scan: "dast", site_profile: "Site Profile", scanner_profile: "Scanner Profile" } }

          specify { expect(errors).to be_empty }

          context "without site profile" do
            before do
              action.delete(:site_profile)
            end

            specify do
              expect(errors).to contain_exactly(
                "property '/scan_execution_policy/0/actions/0' is missing required keys: site_profile")
            end
          end

          context "without scanner profile" do
            before do
              action.delete(:scanner_profile)
            end

            specify { expect(errors).to be_empty }
          end
        end

        context "with variables" do
          let(:action) { { scan: "container_scanning", variables: { "FOO" => "BAR" } } }

          specify { expect(errors).to be_empty }

          context "with invalid key" do
            before do
              action[:variables]["with spaces"] = action[:variables].delete("FOO")
            end

            specify do
              expect(errors.count).to be(1)
              expect(errors.first).to match(
                "property '/scan_execution_policy/0/actions/0/variables/with spaces' is invalid: error_type=schema")
            end
          end
        end

        context "with template" do
          let(:action) { { scan: "container_scanning", template: "latest" } }

          specify { expect(errors).to be_empty }

          context "with invalid value" do
            before do
              action[:template] = 'regular'
            end

            specify do
              expect(errors.count).to be(1)
              expect(errors.first).to match(
                "property '/scan_execution_policy/0/actions/0/template' is not one of: [\"default\", \"latest\"]")
            end
          end
        end
      end

      it_behaves_like "policy_scope"
    end

    shared_examples_for "approval policy validations" do |type|
      let(:scan_execution_policy) { nil }
      let(:scan_result_policy) { build(:scan_result_policy, rules: rules, actions: actions, policy_scope: policy_scope) }
      let(:rules) { [rule].compact }
      let(:actions) { [action].compact }
      let(:action) { nil }
      let(:policy_scope) { {} }

      shared_examples "scan result policy" do |required_rule_keys|
        %i[name enabled rules].each do |key|
          context "without #{key}" do
            before do
              scan_result_policy.delete(key)
            end

            specify do
              expect(errors).to include("property '/#{type}/0' is missing required keys: #{key}")
            end
          end
        end

        required_rule_keys.each do |key|
          context "without #{key}" do
            before do
              rule.delete(key)
            end

            specify do
              expect(errors).to contain_exactly(
                "property '/#{type}/0/rules/0' is missing required keys: #{key}")
            end
          end
        end

        describe "name" do
          context "when too short" do
            before do
              scan_result_policy[:name] = ""
            end

            specify do
              expect(errors).to contain_exactly("property '/#{type}/0/name' is invalid: error_type=minLength")
            end
          end

          context "when too long" do
            before do
              scan_result_policy[:name] = "a" * 256
            end

            specify do
              expect(errors).to contain_exactly("property '/#{type}/0/name' is invalid: error_type=maxLength")
            end
          end
        end

        describe "rules" do
          context "with invalid type" do
            before do
              rule[:type] = "foobar"
            end

            specify do
              expect(errors.count).to be(1)
              expect(errors.first).to match("property '/#{type}/0/rules/0/type' is not one of")
            end
          end
        end

        it_behaves_like "policy_scope"

        describe "approval_settings" do
          let(:scan_result_policy) do
            build(:scan_result_policy, rules: rules, actions: actions, approval_settings: approval_settings)
          end

          context 'with empty object' do
            let(:approval_settings) { {} }

            specify { expect(errors).to be_empty }
          end

          context 'with allowed properties' do
            let(:approval_settings) do
              {
                prevent_approval_by_author: true,
                prevent_approval_by_commit_author: false,
                remove_approvals_with_new_commit: true,
                require_password_to_approve: false,
                block_branch_modification: true,
                prevent_pushing_and_force_pushing: true,
                block_group_branch_modification: true
              }
            end

            specify { expect(errors).to be_empty }
          end

          context 'with additional property' do
            let(:approval_settings) { { additional_key: 'allowed' } }

            specify do
              expect(errors).to be_empty
            end
          end

          describe "block_group_branch_modification" do
            context "in object form" do
              let(:approval_settings) { { enabled: true } }

              specify do
                expect(errors).to be_empty
              end

              context "with exceptions" do
                let(:approval_settings) { { enabled: true, exceptions: %w[foobar] } }

                specify do
                  expect(errors).to be_empty
                end
              end
            end
          end
        end

        describe "actions" do
          let(:approvals_required) { 1 }
          let(:require_approval_action) do
            {
              type: "require_approval",
              approvals_required: approvals_required
            }
          end

          describe 'require_approval' do
            let(:action) { require_approval_action }

            context "with invalid required approvals" do
              let(:approvals_required) { 101 }

              specify do
                expect(errors).to include(
                  "property '/#{type}/0/actions/0/approvals_required' is invalid: error_type=maximum")
              end
            end

            context "without approvers" do
              specify do
                expect(errors).not_to be_empty
              end
            end

            context "with user_approvers" do
              before do
                action[:user_approvers] = %w[foobar]
              end

              specify { expect(errors).to be_empty }

              context "when empty" do
                before do
                  action[:user_approvers] = []
                end

                specify do
                  expect(errors).to contain_exactly(
                    "property '/#{type}/0/actions/0/user_approvers' is invalid: error_type=minItems")
                end
              end
            end

            context "with user_approvers_ids" do
              before do
                action[:user_approvers_ids] = [42]
              end

              specify { expect(errors).to be_empty }

              context "when empty" do
                before do
                  action[:user_approvers_ids] = []
                end

                specify do
                  expect(errors).to contain_exactly(
                    "property '/#{type}/0/actions/0/user_approvers_ids' is invalid: error_type=minItems")
                end
              end
            end

            context "with group_approvers" do
              before do
                action[:group_approvers] = %w[foobar]
              end

              specify { expect(errors).to be_empty }

              context "when empty" do
                before do
                  action[:group_approvers] = []
                end

                specify do
                  expect(errors).to contain_exactly(
                    "property '/#{type}/0/actions/0/group_approvers' is invalid: error_type=minItems")
                end
              end
            end

            context "with group_approvers_ids" do
              before do
                action[:group_approvers_ids] = [42]
              end

              specify { expect(errors).to be_empty }

              context "when empty" do
                before do
                  action[:group_approvers_ids] = []
                end

                specify do
                  expect(errors).to contain_exactly(
                    "property '/#{type}/0/actions/0/group_approvers_ids' is invalid: error_type=minItems")
                end
              end
            end

            context "with role_approvers" do
              before do
                action[:role_approvers] = %w[guest reporter]
              end

              specify { expect(errors).to be_empty }

              context "with invalid role" do
                before do
                  action[:role_approvers] = %w[foobar]
                end

                specify do
                  expect(errors.count).to be(1)
                  expect(errors.first).to match("property '/#{type}/0/actions/0/role_approvers/0' is not one of")
                end
              end
            end

            it_behaves_like "branch_exceptions"
          end

          describe 'send_bot_message' do
            let(:actions) do
              [
                require_approval_action.tap { |action| action[:user_approvers] = %w[foobar] },
                action
              ]
            end

            let(:action) do
              {
                type: "send_bot_message",
                enabled: true
              }
            end

            it { expect(errors).to be_empty }

            context 'when `enabled` property is missing' do
              before do
                action.delete(:enabled)
              end

              it { expect(errors).to be_present }
              it { expect(errors.first).to match("property '/#{type}/0/actions/1' is missing required keys: enabled") }
            end
          end
        end

        context "without actions or approval_settings" do
          before do
            scan_result_policy.delete(:actions)
            scan_result_policy.delete(:approval_settings)
          end

          specify do
            expect(errors).to contain_exactly("property '/#{type}/0' is missing required keys: actions",
              "property '/#{type}/0' is missing required keys: approval_settings")
          end
        end

        context "with approval_settings" do
          let(:approval_settings) do
            {
              prevent_approval_by_author: true,
              prevent_approval_by_commit_author: true,
              remove_approvals_with_new_commit: true,
              require_password_to_approve: false
            }
          end

          specify { expect(errors).to be_empty }

          context "without actions" do
            before do
              scan_result_policy.delete(:actions)
            end

            specify { expect(errors).to be_empty }
          end
        end

        context "with actions" do
          let(:action) do
            {
              type: "require_approval",
              approvals_required: 1,
              user_approvers_ids: [42]
            }
          end

          specify { expect(errors).to be_empty }

          context "without approval_settings" do
            before do
              scan_result_policy.delete(:approval_settings)
            end

            specify { expect(errors).to be_empty }
          end
        end
      end

      shared_examples 'rule has branches or branch_type' do
        context "with branches" do
          before do
            rule[:branches] = %w[master]
            rule.delete(:branch_type)
          end

          specify { expect(errors).to be_empty }

          context "with branch_type" do
            before do
              rule[:branch_type] = "protected"
            end

            specify do
              expect(errors).to contain_exactly("property '/#{type}/0/rules/0' is invalid: error_type=oneOf")
            end
          end
        end

        context "with branch_type" do
          before do
            rule.delete(:branches)
            rule[:branch_type] = "protected"
          end

          specify { expect(errors).to be_empty }

          context "with branches" do
            before do
              rule[:branches] = %w[main]
            end

            specify do
              expect(errors).to contain_exactly("property '/#{type}/0/rules/0' is invalid: error_type=oneOf")
            end
          end
        end

        context "without branches and branch_type" do
          before do
            rule.delete(:branches)
            rule.delete(:branch_type)
          end

          specify do
            expect(errors).to contain_exactly(
              "property '/#{type}/0/rules/0' is missing required keys: branch_type",
              "property '/#{type}/0/rules/0' is missing required keys: branches")
          end
        end
      end

      context "with scan_finding type" do
        let(:rule) do
          {
            type: "scan_finding",
            branches: %w[master],
            scanners: %w[container_scanning secret_detection],
            vulnerabilities_allowed: 0,
            severity_levels: %w[critical high],
            vulnerability_states: %w[detected]
          }
        end

        specify { expect(errors).to be_empty }

        it_behaves_like "scan result policy",
          %i[scanners vulnerabilities_allowed severity_levels vulnerability_states]
        it_behaves_like 'rule has branches or branch_type'

        describe "scanners" do
          before do
            rule[:scanners] = [""]
          end

          specify do
            expect(errors).to contain_exactly(
              "property '/#{type}/0/rules/0/scanners/0' is invalid: error_type=minLength")
          end
        end

        describe "severity_levels" do
          before do
            rule[:severity_levels] = %w[foobar]
          end

          specify do
            expect(errors.count).to be(1)
            expect(errors.first).to match("property '/#{type}/0/rules/0/severity_levels/0' is not one of")
          end
        end

        describe "vulnerability_states" do
          before do
            rule[:vulnerability_states] = %w[foobar]
          end

          specify do
            expect(errors.count).to be(1)
            expect(errors.first).to match(
              "property '/#{type}/0/rules/0/vulnerability_states/0' is not one of")
          end
        end

        describe "vulnerabilities_allowed" do
          context "when value is below the minimum" do
            before do
              rule[:vulnerabilities_allowed] = -1
            end

            specify do
              expect(errors).to contain_exactly(
                "property '/#{type}/0/rules/0/vulnerabilities_allowed' is invalid: error_type=minimum")
            end
          end

          context "when value is above the maximum" do
            before do
              rule[:vulnerabilities_allowed] = 32768
            end

            specify do
              expect(errors).to contain_exactly(
                "property '/#{type}/0/rules/0/vulnerabilities_allowed' is invalid: error_type=maximum")
            end
          end
        end

        describe "vulnerability_age" do
          before do
            rule[:vulnerability_age] = vulnerability_age
          end

          let(:valid_vulnerability_age) do
            { value: 1, operator: 'greater_than', interval: 'week' }
          end

          context 'when vulnerability_age is valid' do
            let(:vulnerability_age) { valid_vulnerability_age }

            specify do
              expect(errors).to be_none
            end
          end

          %i[value operator interval].each do |key|
            context "when vulnerability_age is missing key #{key}" do
              let(:vulnerability_age) { valid_vulnerability_age.except(key) }

              specify do
                expect(errors.count).to eq(1)
                expect(errors.first).to(
                  match "property '/#{type}/0/rules/0/vulnerability_age' is missing required keys: #{key}"
                )
              end
            end
          end

          context "when vulnerability_age is contains additional key" do
            let(:vulnerability_age) { valid_vulnerability_age.merge(additional: true) }

            specify do
              expect(errors.count).to eq(1)
              expect(errors.first).to(
                match "property '/#{type}/0/rules/0/vulnerability_age/additional' is invalid"
              )
            end
          end
        end
      end

      context "with license_finding type" do
        let(:rule) do
          {
            type: "license_finding",
            branches: %w[master],
            match_on_inclusion_license: true,
            license_types: %w[BSD MIT],
            license_states: %w[newly_detected detected]
          }
        end

        specify { expect(errors).to be_empty }

        it_behaves_like 'rule has branches or branch_type'

        context "without match_on_inclusion_license" do
          before do
            rule.delete(:match_on_inclusion_license)
          end

          specify do
            expect(errors).to include(
              "property '/#{type}/0/rules/0' is missing required keys: match_on_inclusion_license"
            )
          end
        end

        describe "license_types" do
          before do
            rule[:license_types] = [""]
          end

          specify do
            expect(errors).to contain_exactly(
              "property '/#{type}/0/rules/0/license_types/0' is invalid: error_type=minLength")
          end

          context "when too long" do
            before do
              rule[:license_types] = ["a" * 256]
            end

            specify do
              expect(errors).to contain_exactly("property '/#{type}/0/rules/0/license_types/0' is invalid: error_type=maxLength")
            end
          end

          context "with repeated licenses" do
            before do
              rule[:license_types] = ["a"] * 2
            end

            specify do
              expect(errors).to contain_exactly("property '/#{type}/0/rules/0/license_types' is invalid: error_type=uniqueItems")
            end
          end

          context "with too many licenses" do
            before do
              licenses = []
              1001.times { |i| licenses << "License #{i}" }
              rule[:license_types] = licenses
            end

            specify do
              expect(errors).to contain_exactly("property '/#{type}/0/rules/0/license_types' is invalid: error_type=maxItems")
            end
          end
        end

        describe "license_states" do
          context "without states" do
            before do
              rule[:license_states] = []
            end

            specify do
              expect(errors).to contain_exactly(
                "property '/#{type}/0/rules/0/license_states' is invalid: error_type=minItems")
            end
          end

          context "with invalid state" do
            before do
              rule[:license_states] = %w[foobar]
            end

            specify do
              expect(errors.count).to be(1)
              expect(errors.first).to match(
                "property '/#{type}/0/rules/0/license_states/0' is not one of")
            end
          end
        end
      end

      context 'with any_merge_request type' do
        let(:rule) do
          {
            type: 'any_merge_request',
            branches: %w[master],
            commits: 'any'
          }
        end

        specify { expect(errors).to be_empty }

        it_behaves_like 'scan result policy', %i[commits]
        it_behaves_like 'rule has branches or branch_type'

        describe 'commits' do
          before do
            rule[:commits] = 'invalid'
          end

          specify do
            expect(errors).to contain_exactly(
              "property '/#{type}/0/rules/0/commits' is not one of: [\"any\", \"unsigned\"]")
          end
        end
      end
    end

    describe "scan result policies" do
      it_behaves_like 'approval policy validations', 'scan_result_policy'
    end

    describe "approval policies" do
      it_behaves_like 'approval policy validations', 'approval_policy' do
        let(:policy_yaml) do
          {
            approval_policy: [scan_result_policy].compact
          }
        end
      end
    end

    describe "pipeline execution policies" do
      let(:pipeline_execution_policy) { build(:pipeline_execution_policy, policy_scope: policy_scope) }
      let(:policy_scope) { {} }

      it { expect(errors).to be_empty }

      it_behaves_like "policy_scope"

      describe 'max items' do
        let(:policy_yaml) do
          {
            pipeline_execution_policy: pipeline_execution_policies
          }
        end

        context 'when policies are at the limit' do
          let(:pipeline_execution_policies) do
            build_list(:pipeline_execution_policy, ::Security::PipelineExecutionPolicy::POLICY_LIMIT)
          end

          it { expect(errors).to be_empty }
        end

        context 'when policies are over the limit' do
          let(:pipeline_execution_policies) do
            build_list(:pipeline_execution_policy, ::Security::PipelineExecutionPolicy::POLICY_LIMIT + 1)
          end

          it do
            expect(errors).to contain_exactly("property '/pipeline_execution_policy' is invalid: error_type=maxItems")
          end
        end
      end

      describe 'content' do
        context 'without content' do
          let(:pipeline_execution_policy) { build(:pipeline_execution_policy, content: {}) }

          it do
            expect(errors).to contain_exactly(
              "property '/pipeline_execution_policy/0/content' is missing required keys: include"
            )
          end
        end

        context 'when include is missing required properties' do
          let(:pipeline_execution_policy) { build(:pipeline_execution_policy, content: { include: [{}] }) }

          it do
            expect(errors).to contain_exactly(
              "property '/pipeline_execution_policy/0/content/include/0' is missing required keys: project, file"
            )
          end
        end

        context 'when include is an empty array' do
          let(:pipeline_execution_policy) do
            build(:pipeline_execution_policy, content: { include: [] })
          end

          it do
            expect(errors).to contain_exactly(
              "property '/pipeline_execution_policy/0/content/include' is invalid: error_type=minItems"
            )
          end
        end

        context 'when include is contains more than 1 item' do
          let(:pipeline_execution_policy) do
            build(:pipeline_execution_policy, content: {
              include: [
                { project: '', file: '' }, { project: '', file: '' }
              ]
            })
          end

          it do
            expect(errors).to contain_exactly(
              "property '/pipeline_execution_policy/0/content/include' is invalid: error_type=maxItems"
            )
          end
        end
      end
    end

    context 'when file is valid' do
      it { is_expected.to eq([]) }
    end

    context 'when policy is passed as argument' do
      let_it_be(:policy_yaml) { nil }
      let_it_be(:policy) { { scan_execution_policy: [build(:scan_execution_policy, :with_schedule)] } }

      context 'when scan type is secret_detection' do
        it 'returns false if extra fields are present' do
          invalid_policy = policy.deep_dup
          invalid_policy[:scan_execution_policy][0][:actions][0][:scan] = 'secret_detection'
          invalid_policy[:scan_execution_policy][0][:actions][0][:variables] = { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false' }
          invalid_policy[:scan_execution_policy][0][:actions][0][:template] = 'default'
          invalid_policy[:scan_execution_policy][0][:rules][0][:cadence] = 'invalid * * * *'

          expect(security_orchestration_policy_configuration.policy_configuration_validation_errors(invalid_policy)).to contain_exactly(
            "property '/scan_execution_policy/0/actions/0' is invalid: error_type=maxProperties",
            "property '/scan_execution_policy/0/rules/0/cadence' does not match pattern: (@(yearly|annually|monthly|weekly|daily|midnight|noon|hourly))|(((\\*|(\\-?\\d+\\,?)+)(\\/\\d+)?|last|L|(sun|mon|tue|wed|thu|fri|sat|SUN|MON|TUE|WED|THU|FRI|SAT\\-|\\,)+|(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|\\-|\\,)+)\\s?){5,6}"
          )
        end

        it 'returns true if extra fields are not present' do
          valid_policy = policy.deep_dup
          valid_policy[:scan_execution_policy][0][:actions][0] = { scan: 'secret_detection' }

          expect(security_orchestration_policy_configuration.policy_configuration_validation_errors(valid_policy)).to eq([])
        end
      end
    end
  end

  describe '#active_scan_execution_policies' do
    let(:enforce_dast_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy)]) }
    let(:policy_yaml) { fixture_file('security_orchestration.yml', dir: 'ee') }

    let(:expected_active_policies) do
      [
        build(:scan_execution_policy, name: 'Run DAST in every pipeline', rules: [{ type: 'pipeline', branches: %w[production] }]),
        build(:scan_execution_policy, name: 'Run DAST in every pipeline_v1', rules: [{ type: 'pipeline', branches: %w[master] }]),
        build(:scan_execution_policy, name: 'Run DAST in every pipeline_v3', rules: [{ type: 'pipeline', branches: %w[master] }]),
        build(:scan_execution_policy, name: 'Run DAST in every pipeline_v4', rules: [{ type: 'pipeline', branches: %w[master] }]),
        build(:scan_execution_policy, name: 'Run DAST in every pipeline_v5', rules: [{ type: 'pipeline', branches: %w[master] }])
      ]
    end

    subject(:active_scan_execution_policies) { security_orchestration_policy_configuration.active_scan_execution_policies }

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
    end

    it 'returns only enabled policies' do
      expect(active_scan_execution_policies).to eq(expected_active_policies)
    end
  end

  describe '#active_scan_execution_policies_for_pipelines' do
    let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy_pipeline_1, policy_pipeline_2, policy_schedule]) }

    let(:policy_pipeline_1) { build(:scan_execution_policy, name: 'Run DAST in every pipeline', rules: [{ type: 'pipeline', branches: %w[production] }]) }
    let(:policy_pipeline_2) { build(:scan_execution_policy, name: 'Run DAST in every pipeline_v1', rules: [{ type: 'pipeline', branches: %w[master] }]) }
    let(:policy_schedule) { build(:scan_execution_policy, name: 'Run DAST every 20 mins', rules: [{ type: 'schedule', branches: %w[production], cadence: '*/20 * * * *' }]) }

    let(:expected_active_scan_execution_policies_for_pipelines) { [policy_pipeline_1, policy_pipeline_2] }

    subject(:active_scan_execution_policies_for_pipelines) { security_orchestration_policy_configuration.active_scan_execution_policies_for_pipelines }

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
    end

    it 'returns only active scan execution policies for pipelines' do
      expect(active_scan_execution_policies_for_pipelines).to eq(expected_active_scan_execution_policies_for_pipelines)
    end
  end

  describe '#active_policy_names_with_dast_site_profile' do
    let(:policy_yaml) do
      build(:orchestration_policy_yaml, scan_execution_policy: [
        build(
          :scan_execution_policy,
          name: 'Run DAST in every pipeline',
          actions: [
            { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' },
            { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile 2' }
          ])
      ])
    end

    it 'returns list of policy names where site profile is referenced' do
      expect(security_orchestration_policy_configuration.active_policy_names_with_dast_site_profile('Site Profile')).to contain_exactly('Run DAST in every pipeline')
    end
  end

  describe '#active_policy_names_with_dast_scanner_profile' do
    let(:enforce_dast_yaml) do
      build(:orchestration_policy_yaml, scan_execution_policy: [
        build(
          :scan_execution_policy,
          name: 'Run DAST in every pipeline',
          actions: [
            { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' },
            { scan: 'dast', site_profile: 'Site Profile 2', scanner_profile: 'Scanner Profile' }
          ])
      ])
    end

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(enforce_dast_yaml)
    end

    it 'returns list of policy names where site profile is referenced' do
      expect(security_orchestration_policy_configuration.active_policy_names_with_dast_scanner_profile('Scanner Profile')).to contain_exactly('Run DAST in every pipeline')
    end
  end

  describe '#policy_last_updated_by' do
    let(:merged_merge_request) do
      create(:merge_request, :merged, author: security_policy_management_project.first_owner)
    end

    subject(:policy_last_updated_by) { security_orchestration_policy_configuration.policy_last_updated_by }

    before do
      allow(security_policy_management_project).to receive(:merge_requests).and_return(MergeRequest.where(id: merged_merge_request&.id))
    end

    context 'when last merged merge request to policy file exists' do
      it { is_expected.to eq(security_policy_management_project.first_owner) }
    end

    context 'when last merge request to policy file does not exist' do
      let(:merged_merge_request) {}

      it { is_expected.to be_nil }
    end
  end

  describe '#policy_last_updated_at' do
    let(:last_commit_updated_at) { Time.zone.now }
    let(:commit) { create(:commit) }

    subject(:policy_last_updated_at) { security_orchestration_policy_configuration.policy_last_updated_at }

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:last_commit_for_path).and_return(commit)
    end

    context 'when last commit to policy file exists' do
      it "returns commit's updated date" do
        commit.committed_date = last_commit_updated_at

        is_expected.to eq(policy_last_updated_at)
      end
    end

    context 'when last commit to policy file does not exist' do
      let(:commit) {}

      it { is_expected.to be_nil }
    end

    it_behaves_like 'captures git errors', :last_commit_for_path
  end

  describe '#delete_all_schedules' do
    let(:rule_schedule) { create(:security_orchestration_policy_rule_schedule, security_orchestration_policy_configuration: security_orchestration_policy_configuration) }

    subject(:delete_all_schedules) { security_orchestration_policy_configuration.delete_all_schedules }

    it 'deletes all schedules belonging to configuration' do
      delete_all_schedules

      expect(security_orchestration_policy_configuration.rule_schedules).to be_empty
    end
  end

  describe '#active_scan_result_policies' do
    let(:scan_result_yaml) { build(:orchestration_policy_yaml, scan_result_policy: [build(:scan_result_policy)]) }
    let(:policy_yaml) { fixture_file('security_orchestration.yml', dir: 'ee') }

    subject(:active_scan_result_policies) { security_orchestration_policy_configuration.active_scan_result_policies }

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
    end

    it 'returns only enabled policies' do
      expect(active_scan_result_policies.pluck(:enabled).uniq).to contain_exactly(true)
    end

    it 'returns only 5 from all active policies' do
      expect(active_scan_result_policies.count).to be(5)
    end

    context 'when policy configuration is configured for namespace' do
      let(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace, security_policy_management_project: security_policy_management_project)
      end

      it 'returns only enabled policies' do
        expect(active_scan_result_policies.pluck(:enabled).uniq).to contain_exactly(true)
      end

      it 'returns only 5 from all active policies' do
        expect(active_scan_result_policies.count).to be(5)
      end
    end
  end

  describe '#applicable_scan_result_policies_for_project' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let(:policy_yaml) do
      build(:orchestration_policy_yaml, scan_result_policy: [
        build(:scan_result_policy, name: 'Active policy'),
        build(:scan_result_policy, name: 'Disabled policy', enabled: false),
        build(:scan_result_policy, name: 'Not applicable policy', policy_scope: {
          projects: {
            excluding: [{ id: project.id }]
          }
        })
      ])
    end

    subject(:applicable_policies) do
      security_orchestration_policy_configuration.applicable_scan_result_policies_for_project(project)
    end

    it 'returns only active applicable policies' do
      expect(applicable_policies).to be_one
      expect(applicable_policies.first[:name]).to eq('Active policy')
    end
  end

  describe '#scan_result_policies' do
    let(:policy_yaml) { fixture_file('security_orchestration.yml', dir: 'ee') }

    subject(:scan_result_policies) { security_orchestration_policy_configuration.scan_result_policies }

    it 'returns all scan result policies' do
      expect(scan_result_policies.pluck(:enabled)).to contain_exactly(true, true, false, true, true, true, true, true)
    end
  end

  describe '#project?' do
    subject { security_orchestration_policy_configuration.project? }

    context 'when project is assigned to policy configuration' do
      it { is_expected.to eq true }
    end

    context 'when namespace is assigned to policy configuration' do
      let(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

      it { is_expected.to eq false }
    end
  end

  describe '#namespace?' do
    subject { security_orchestration_policy_configuration.namespace? }

    context 'when project is assigned to policy configuration' do
      it { is_expected.to eq false }
    end

    context 'when namespace is assigned to policy configuration' do
      let(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

      it { is_expected.to eq true }
    end
  end

  describe '#source' do
    subject { security_orchestration_policy_configuration.source }

    context 'when project is assigned to policy configuration' do
      it { is_expected.to eq security_orchestration_policy_configuration.project }
    end

    context 'when namespace is assigned to policy configuration' do
      let(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration, :namespace) }

      it { is_expected.to eq security_orchestration_policy_configuration.namespace }
    end
  end

  describe '#compliance_framework_ids_with_policy_index' do
    subject { security_orchestration_policy_configuration.compliance_framework_ids_with_policy_index }

    context 'for project level configuration' do
      it { is_expected.to eq([]) }
    end

    context 'for group level configuration' do
      let(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration,
          security_policy_management_project: security_policy_management_project,
          namespace: create(:group),
          project: nil
        )
      end

      context 'without compliance framework ids' do
        it { is_expected.to eq([]) }
      end

      context 'with compliance framework ids' do
        let(:policy_yaml) do
          build(:orchestration_policy_yaml,
            scan_execution_policy: [build(:scan_execution_policy, policy_scope: { compliance_frameworks: [{ id: 2 }, { id: 3 }] })],
            scan_result_policy: [build(:scan_result_policy, policy_scope: { compliance_frameworks: [{ id: 1 }, { id: 2 }] })]
          )
        end

        it { is_expected.to match_array([{ framework_ids: [1, 2], policy_index: 0 }, { framework_ids: [2, 3], policy_index: 1 }]) }
      end
    end
  end

  describe '#delete_scan_finding_rules' do
    subject(:delete_scan_finding_rules) { security_orchestration_policy_configuration.delete_scan_finding_rules }

    let(:project) { security_orchestration_policy_configuration.project }
    let(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let(:security_orchestration_policy_configuration_id) { security_orchestration_policy_configuration.id }

    before do
      create(:approval_project_rule,
        :scan_finding,
        project: project,
        security_orchestration_policy_configuration_id: security_orchestration_policy_configuration_id)
      create(:report_approver_rule,
        :scan_finding,
        merge_request: merge_request,
        security_orchestration_policy_configuration_id: security_orchestration_policy_configuration_id)
    end

    shared_examples 'approval rules deletion' do
      it 'deletes project approval rules' do
        expect { delete_scan_finding_rules }.to change(ApprovalProjectRule, :count).from(1).to(0)
      end

      it 'deletes merge request approval rules' do
        expect { delete_scan_finding_rules }.to change(ApprovalMergeRequestRule, :count).from(1).to(0)
      end

      it_behaves_like 'does not deletes merge request approval rules of merged MR'
    end

    context 'when associated to a project' do
      it_behaves_like 'approval rules deletion'
    end

    context 'when associated to namespace' do
      let(:project) { create(:project) }
      let(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace)
      end

      it_behaves_like 'approval rules deletion'
    end
  end

  describe '#delete_scan_finding_rules_for_project' do
    subject(:delete_scan_finding_rules_for_project) { security_orchestration_policy_configuration.delete_scan_finding_rules_for_project(project.id) }

    let(:project) { security_orchestration_policy_configuration.project }
    let(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let(:security_orchestration_policy_configuration_id) { security_orchestration_policy_configuration.id }

    before do
      create(:approval_project_rule,
        :scan_finding,
        project: project,
        security_orchestration_policy_configuration_id: security_orchestration_policy_configuration_id)
      create(:report_approver_rule,
        :scan_finding,
        merge_request: merge_request,
        security_orchestration_policy_configuration_id: security_orchestration_policy_configuration_id)
    end

    it 'deletes project approval rules' do
      expect { delete_scan_finding_rules_for_project }.to change(ApprovalProjectRule, :count).from(1).to(0)
    end

    it 'deletes merge request approval rules' do
      expect { delete_scan_finding_rules_for_project }.to change(ApprovalMergeRequestRule, :count).from(1).to(0)
    end

    context 'with unrelated resources' do
      let_it_be(:unrelated_project) { create(:project) }
      let(:unrelated_mr) { create(:merge_request, target_project: unrelated_project, source_project: unrelated_project) }

      before do
        create(:approval_project_rule,
          :scan_finding,
          project: unrelated_project,
          security_orchestration_policy_configuration_id: security_orchestration_policy_configuration_id)
        create(:report_approver_rule,
          :scan_finding,
          merge_request: unrelated_mr,
          security_orchestration_policy_configuration_id: security_orchestration_policy_configuration_id)
      end

      it 'does not delete unrelated project approval rules' do
        expect { delete_scan_finding_rules_for_project }.to change(ApprovalProjectRule, :count).from(2).to(1)
      end

      it 'does not delete unrelated merge request approval rules' do
        expect { delete_scan_finding_rules_for_project }.to change(ApprovalMergeRequestRule, :count).from(2).to(1)
      end

      it_behaves_like 'does not deletes merge request approval rules of merged MR'
    end
  end

  describe '#delete_software_license_policies' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:other_configuration) { create(:security_orchestration_policy_configuration) }

    let_it_be(:read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration) }
    let_it_be(:other_read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: other_configuration) }

    let_it_be(:policy) { create(:software_license_policy, scan_result_policy_read: read) }
    let_it_be(:other_policy) { create(:software_license_policy, scan_result_policy_read: other_read) }

    subject(:delete) { configuration.delete_software_license_policies }

    it "deletes software license policies" do
      expect { delete }.to change { SoftwareLicensePolicy.exists?(policy.id) }.to(false)
    end

    it "does not delete other software license policies" do
      expect { delete }.not_to change { SoftwareLicensePolicy.exists?(other_policy.id) }.from(true)
    end
  end

  describe '#delete_software_license_policies_for_project' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:other_project) { create(:project, namespace: namespace) }
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration, namespace: namespace, project: nil) }
    let_it_be(:other_configuration) { create(:security_orchestration_policy_configuration, project: other_project) }

    let_it_be(:scan_result_policy_read) do
      create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: project)
    end

    let_it_be(:scan_result_policy_read_other_project) do
      create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: other_project)
    end

    let_it_be(:scan_result_policy_read_other_configuration) do
      create(:scan_result_policy_read, security_orchestration_policy_configuration: other_configuration, project: other_project)
    end

    let!(:software_license_without_scan_result_policy) do
      create(:software_license_policy, project: project)
    end

    let!(:software_license_with_scan_result_policy) do
      create(:software_license_policy, project: project,
        scan_result_policy_read: scan_result_policy_read)
    end

    let!(:software_license_with_scan_result_policy_other_configuration) do
      create(:software_license_policy, project: other_project,
        scan_result_policy_read: scan_result_policy_read_other_configuration)
    end

    let!(:software_license_with_scan_result_policy_other_project) do
      create(:software_license_policy, project: other_project,
        scan_result_policy_read: scan_result_policy_read_other_project)
    end

    it 'deletes project scan_result_policy_reads' do
      configuration.delete_software_license_policies_for_project(project)

      software_license_policies = SoftwareLicensePolicy.where(project_id: project.id)
      other_project_software_license_policies = SoftwareLicensePolicy.where(project_id: other_project.id)

      expect(software_license_policies).to match_array([software_license_without_scan_result_policy])
      expect(other_project_software_license_policies).to match_array([software_license_with_scan_result_policy_other_configuration, software_license_with_scan_result_policy_other_project])
    end
  end

  describe '#delete_policy_violations' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:other_configuration) { create(:security_orchestration_policy_configuration) }

    let_it_be(:read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration) }
    let_it_be(:other_read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: other_configuration) }

    let_it_be(:violation) { create(:scan_result_policy_violation, scan_result_policy_read: read) }
    let_it_be(:other_violation) { create(:scan_result_policy_violation, scan_result_policy_read: other_read) }

    subject(:delete) { configuration.delete_policy_violations }

    it "deletes configuration's scan result policy violations" do
      expect { delete }.to change { Security::ScanResultPolicyViolation.exists?(violation.id) }.to(false)
    end

    it "does not delete other scan result policy violations" do
      expect { delete }.not_to change { Security::ScanResultPolicyViolation.exists?(other_violation.id) }.from(true)
    end
  end

  describe '#delete_policy_violations_for_project' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:inherited_configuration) { create(:security_orchestration_policy_configuration, namespace: configuration.project.group) }
    let_it_be(:other_configuration) { create(:security_orchestration_policy_configuration) }

    let_it_be(:project) { configuration.project }
    let_it_be(:other_project) { other_configuration.project }

    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let_it_be(:other_merge_request) { create(:merge_request, source_project: other_project, target_project: other_project) }

    let_it_be(:scan_result_policy_read) do
      create(
        :scan_result_policy_read,
        security_orchestration_policy_configuration: configuration,
        project: project)
    end

    let_it_be(:inherited_scan_result_policy_read) do
      create(
        :scan_result_policy_read,
        security_orchestration_policy_configuration: inherited_configuration,
        project: project)
    end

    let_it_be(:other_scan_result_policy_read) do
      create(
        :scan_result_policy_read,
        security_orchestration_policy_configuration: other_configuration,
        project: other_project)
    end

    let_it_be(:violation) do
      create(
        :scan_result_policy_violation,
        project: project,
        merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:inherited_violation) do
      create(
        :scan_result_policy_violation,
        project: project,
        merge_request: merge_request,
        scan_result_policy_read: inherited_scan_result_policy_read)
    end

    let_it_be(:other_violation) do
      create(
        :scan_result_policy_violation,
        project: other_project,
        merge_request: other_merge_request,
        scan_result_policy_read: other_scan_result_policy_read)
    end

    it 'deletes scan_result_policy_violations related to the project and configuration' do
      configuration.delete_policy_violations_for_project(project)

      project_violations = project.scan_result_policy_violations.where(scan_result_policy_id: scan_result_policy_read.id)
      inherited_violations = project.scan_result_policy_violations.where(scan_result_policy_id: inherited_scan_result_policy_read.id)

      expect(project_violations.count).to be(0)
      expect(inherited_violations.count).to be(1)
      expect(other_project.scan_result_policy_violations.count).to be(1)
    end

    it 'changes policy violation count only for the configuration' do
      expect { configuration.delete_policy_violations_for_project(project) }.to change { project.scan_result_policy_violations.count }.by(-1)
    end
  end

  describe '#delete_scan_result_policy_reads' do
    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:other_configuration) { create(:security_orchestration_policy_configuration) }

    let_it_be(:read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration) }
    let_it_be(:other_read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: other_configuration) }

    subject(:delete) { configuration.delete_scan_result_policy_reads }

    it "deletes scan_result_policy_reads" do
      expect { delete }.to change { Security::ScanResultPolicyRead.exists?(read.id) }.to(false)
    end

    it "does not delete other scan_result_policy_reads" do
      expect { delete }.not_to change { Security::ScanResultPolicyRead.exists?(other_read.id) }.from(true)
    end
  end

  describe '#delete_scan_result_policy_reads_for_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:other_project) { create(:project) }

    let_it_be(:configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:other_configuration) { create(:security_orchestration_policy_configuration) }

    let!(:read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: project) }
    let_it_be(:other_read) { create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: other_project) }

    subject(:delete) { configuration.delete_scan_result_policy_reads_for_project(project) }

    it "deletes a project's scan_result_policy_reads" do
      expect { delete }.to change { project.scan_result_policy_reads.count }.by(-1)
    end

    it "does not delete other projects' scan_result_policy_reads" do
      expect { delete }.not_to change { other_project.scan_result_policy_reads.count }
    end

    context "when scan_result_policy_read belongs to other configuration" do
      let!(:read) do
        create(:scan_result_policy_read, security_orchestration_policy_configuration: other_configuration, project: project)
      end

      it "does not delete it" do
        expect { delete }.not_to change { project.scan_result_policy_reads.count }
      end
    end
  end

  shared_context 'for policies with pipeline and scheduled rules' do
    before do
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
    end

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, scan_execution_policy: scan_execution_policies, scan_result_policy: scan_result_policies)
    end

    let(:scan_execution_policies) { [dast_policy, container_scanning_policy, sast_policy_with_schedule] }

    let(:dast_policy) do
      build(:scan_execution_policy,
        actions: [{ scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }])
    end

    let(:container_scanning_policy) { build(:scan_execution_policy, actions: [{ scan: 'container_scanning' }]) }
    let(:sast_policy_with_schedule) { build(:scan_execution_policy, :with_schedule, actions: [{ scan: 'sast' }]) }
    let(:scan_result_policies) { [build(:scan_result_policy)] }

    let_it_be(:project) { create(:project, :repository) }
    let(:security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project,
        security_policy_management_project: security_policy_management_project)
    end
  end

  describe "#active_policies_scan_actions_for_project" do
    include_context 'for policies with pipeline and scheduled rules'

    subject(:active_scan_actions) { security_orchestration_policy_configuration.active_policies_scan_actions_for_project('refs/heads/master', project) }

    context "with matched branches" do
      it "returns active scan policies" do
        expect(active_scan_actions).to contain_exactly(
          *dast_policy[:actions],
          *container_scanning_policy[:actions],
          *sast_policy_with_schedule[:actions]
        )
      end
    end

    context 'with policy scope' do
      let(:policy_applicable) { true }

      before do
        allow_next_instance_of(Security::SecurityOrchestrationPolicies::PolicyBranchesService) do |service|
          allow(service).to receive(:scan_execution_branches).and_return(Set[default_branch])
        end

        allow_next_instance_of(Security::SecurityOrchestrationPolicies::PolicyScopeService) do |service|
          allow(service).to receive(:policy_applicable?).and_return(policy_applicable)
        end
      end

      it 'returns active scan policies' do
        expect(active_scan_actions)
          .to contain_exactly(
            *dast_policy[:actions],
            *container_scanning_policy[:actions],
            *sast_policy_with_schedule[:actions]
          )
      end

      context 'when policy is not applicable' do
        let(:policy_applicable) { false }

        it 'is empty' do
          expect(active_scan_actions).to be_empty
        end
      end
    end

    context "with disabled scan policies" do
      let(:container_scanning_policy) do
        build(:scan_execution_policy, actions: [{ scan: 'container_scanning' }], enabled: false)
      end

      it "filters" do
        expect(active_scan_actions).to contain_exactly(*dast_policy[:actions], *sast_policy_with_schedule[:actions])
      end
    end

    context "with scan policies targeting other branch" do
      let(:container_scanning_policy) do
        build(
          :scan_execution_policy,
          actions: [{ scan: 'container_scanning' }],
          rules: [{ type: 'pipeline', branches: [default_branch.reverse] }]
        )
      end

      it "filters" do
        expect(active_scan_actions).to contain_exactly(*dast_policy[:actions], *sast_policy_with_schedule[:actions])
      end
    end
  end

  describe 'active_policies_pipeline_scan_actions_for_project' do
    include_context 'for policies with pipeline and scheduled rules'

    subject(:active_scan_actions) { security_orchestration_policy_configuration.active_policies_pipeline_scan_actions_for_project('refs/heads/master', project) }

    it 'invokes active_policies_scan_actions_for_project' do
      expect(security_orchestration_policy_configuration)
        .to receive(:active_policies_scan_actions_for_project).and_call_original

      active_scan_actions
    end

    it 'excludes the scheduled rules' do
      expect(active_scan_actions).to contain_exactly(*dast_policy[:actions], *container_scanning_policy[:actions])
    end
  end

  describe '#active_pipeline_execution_policies' do
    let(:pipeline_execution_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: [build(:pipeline_execution_policy)]) }
    let(:policy_yaml) { fixture_file('security_orchestration.yml', dir: 'ee') }

    subject(:active_pipeline_execution_policies) { security_orchestration_policy_configuration.active_pipeline_execution_policies }

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
    end

    it 'returns only enabled policies' do
      expect(active_pipeline_execution_policies.pluck(:enabled).uniq).to contain_exactly(true)
    end

    it 'returns only 5 from all active policies' do
      expect(active_pipeline_execution_policies.count).to be(5)
    end

    context 'when policy configuration is configured for namespace' do
      let(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace, security_policy_management_project: security_policy_management_project)
      end

      it 'returns only enabled policies' do
        expect(active_pipeline_execution_policies.pluck(:enabled).uniq).to contain_exactly(true)
      end

      it 'returns only 5 from all active policies' do
        expect(active_pipeline_execution_policies.count).to be(5)
      end
    end
  end

  describe '#active_ci_component_sources_policies' do
    let(:ci_component_sources_yaml) do
      build(:orchestration_policy_yaml, ci_component_sources_policy: [build(:ci_component_sources_policy)])
    end

    let(:policy_yaml) { fixture_file('security_orchestration.yml', dir: 'ee') }

    subject(:active_ci_component_sources_policies) do
      security_orchestration_policy_configuration.active_ci_component_sources_policies
    end

    before do
      allow(security_policy_management_project).to receive(:repository).and_return(repository)
      allow(repository).to receive(:blob_data_at).with(default_branch, Security::OrchestrationPolicyConfiguration::POLICY_PATH).and_return(policy_yaml)
    end

    it 'returns only enabled policies' do
      expect(active_ci_component_sources_policies.pluck(:enabled).uniq).to contain_exactly(true)
    end

    it 'returns only the limit (5) from all active policies' do
      expect(active_ci_component_sources_policies.count).to be(5)
    end

    context 'when policy configuration is configured for namespace' do
      let(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace, security_policy_management_project: security_policy_management_project)
      end

      it 'returns only enabled policies' do
        expect(active_ci_component_sources_policies.pluck(:enabled).uniq).to contain_exactly(true)
      end

      it 'returns only 5 from all active policies' do
        expect(active_ci_component_sources_policies.count).to be(5)
      end
    end
  end
end
