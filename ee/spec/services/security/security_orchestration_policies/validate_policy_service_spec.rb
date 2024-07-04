# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ValidatePolicyService, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let(:service) { described_class.new(container: container, params: { policy: policy, validate_approvals_required: validate_approvals_required }) }
    let(:validate_approvals_required) { true }
    let(:enabled) { true }
    let(:policy_type) { 'scan_execution_policy' }
    let(:name) { 'New policy' }
    let(:rule) { { agents: { production: {} } } }
    let(:rules) { [rule] }
    let(:policy) do
      {
        type: policy_type,
        name: name,
        enabled: enabled,
        rules: rules
      }
    end

    subject(:result) { service.execute }

    shared_examples 'checks only if policy is enabled' do
      let(:enabled) { false }

      it { expect(result[:status]).to eq(:success) }
    end

    shared_examples 'sets validation errors' do |message:, field: described_class::DEFAULT_VALIDATION_ERROR_FIELD, level: :error, title: nil|
      describe 'validation errors' do
        subject(:errors) { result[:validation_errors] }

        specify { expect(errors).to be_one }

        specify do
          expect(errors.first).to include(field: field, level: level, message: message, title: title || anything)
        end
      end
    end

    shared_examples 'checks policy type' do
      context 'when policy type is not provided' do
        let(:policy_type) { nil }

        it { expect(result[:status]).to eq(:error) }
        it { expect(result[:message]).to eq('Invalid policy') }
        it { expect(result[:details]).to match_array(['Invalid policy type']) }

        it_behaves_like 'sets validation errors', message: 'Invalid policy type'
      end

      context 'when policy type is invalid' do
        let(:policy_type) { 'invalid_policy_type' }

        it { expect(result[:status]).to eq(:error) }
        it { expect(result[:message]).to eq('Invalid policy') }
        it { expect(result[:details]).to match_array(['Invalid policy type']) }

        it_behaves_like 'sets validation errors', message: 'Invalid policy type'
      end

      context 'when policy type is valid' do
        it { expect(result[:status]).to eq(:success) }
      end
    end

    shared_examples 'checks policy name' do
      context 'when policy name is not provided' do
        let(:name) { nil }

        it { expect(result[:status]).to eq(:error) }
        it { expect(result[:message]).to eq('Invalid policy') }
        it { expect(result[:details]).to match_array(['Empty policy name']) }

        it_behaves_like 'sets validation errors', message: 'Empty policy name'
      end

      context 'when policy name is invalid' do
        let(:name) { '' }

        it { expect(result[:status]).to eq(:error) }
        it { expect(result[:message]).to eq('Invalid policy') }
        it { expect(result[:details]).to match_array(['Empty policy name']) }

        it_behaves_like 'sets validation errors', message: 'Empty policy name'
      end

      context 'when policy name is valid' do
        it { expect(result[:status]).to eq(:success) }
      end
    end

    shared_examples 'checks if branches are provided in rule' do
      context 'when rule has agents defined' do
        let(:rule) do
          {
            agents: {
              production: {}
            },
            branches: branches
          }
        end

        context 'when branches are missing' do
          let(:branches) { nil }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when branches are provided' do
          let(:branches) { ['master'] }

          it { expect(result[:status]).to eq(:success) }
        end
      end

      context 'when rule does not have agents defined' do
        let(:rule) do
          {
            branches: branches
          }
        end

        context 'when branches and branch_type are missing' do
          using RSpec::Parameterized::TableSyntax

          where(:policy_type, :branches, :branch_type, :status, :details, :field) do
            'scan_result_policy'        | nil | nil | :success | nil                                                     | nil
            'approval_policy'           | nil | nil | :success | nil                                                     | nil
            'pipeline_execution_policy' | nil | nil | :success | nil                                                     | nil
            'scan_execution_policy'     | nil | nil | :error   | ['Policy cannot be enabled without branch information'] | :branches
          end

          with_them do
            before do
              rule[:branches] = branches if branches
              rule[:branch_type] = branch_type if branch_type
            end

            it { expect(result[:status]).to eq(status) }
            it { expect(result[:details]).to eq(details) }

            it_behaves_like 'sets validation errors', field: :branches, message: 'Policy cannot be enabled without branch information' do
              before do
                skip if status != :error
              end
            end

            it_behaves_like 'checks only if policy is enabled'
          end
        end

        context 'when branches are provided' do
          let(:branches) { ['master'] }

          it { expect(result[:status]).to eq(:success) }
        end
      end
    end

    shared_examples 'checks if branches are defined in the project' do
      context 'when rule has agents defined' do
        let(:rule) do
          {
            agents: {
              production: {}
            },
            branches: branches
          }
        end

        context 'when branches are defined for project' do
          let(:branches) { ['master'] }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when branches are not defined for project' do
          let(:branches) { ['non-existing-branch'] }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when pattern does not match any branch defined for project' do
          let(:branches) { ['master', 'production-*', 'test-*'] }

          it { expect(result[:status]).to eq(:success) }
        end
      end

      context 'when rule does not have agents defined' do
        let(:rule) do
          {
            branches: branches
          }
        end

        context 'when branches are defined for project' do
          let(:branches) { ['master'] }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when branches are not defined for project' do
          let(:branches) { ['non-exising-branch'] }

          it { expect(result[:status]).to eq(:error) }
          it { expect(result[:message]).to eq('Invalid policy') }
          it { expect(result[:details]).to match_array(['Policy cannot be enabled for non-existing branches (non-exising-branch)']) }

          it_behaves_like 'checks only if policy is enabled'

          context 'with pipeline_execution_policy' do
            let(:policy_type) { :pipeline_execution_policy }

            it { expect(result[:status]).to eq(:success) }
          end
        end

        context 'when branches are defined as pattern' do
          context 'when pattern matches at least one branch defined for project' do
            let(:branches) { ['*'] }

            it { expect(result[:status]).to eq(:success) }
          end

          context 'when pattern does not match any branch defined for project' do
            let(:branches) { ['master', 'production-*', 'test-*'] }

            it { expect(result[:status]).to eq(:error) }
            it { expect(result[:message]).to eq('Invalid policy') }
            it { expect(result[:details]).to match_array(['Policy cannot be enabled for non-existing branches (production-*, test-*)']) }

            it_behaves_like 'checks only if policy is enabled'
          end
        end
      end
    end

    shared_examples 'checks if required approvals exceed eligible approvers' do
      Security::ScanResultPolicy::SCAN_RESULT_POLICY_TYPES.each do |type|
        context "when policy_type is #{type}" do
          let(:policy_type) { type }
          let(:user) { create(:user) }

          before do
            ::Gitlab::Database.allow_cross_joins_across_databases(url:
              "https://gitlab.com/gitlab-org/gitlab/-/issues/422405") do
              container.users.delete_all
            end

            container.add_developer(user)

            policy[:actions] = [action]
          end

          shared_examples 'fails validation' do
            specify do
              expect(result).to include(status: :error,
                message: 'Invalid policy',
                details: ['Required approvals exceed eligible approvers.'])
            end

            it_behaves_like 'sets validation errors',
              field: :approvers_ids,
              message: 'Required approvals exceed eligible approvers.',
              title: 'Logic error'
          end

          shared_examples 'passes validation' do
            specify do
              expect(result).to eq(status: :success)
            end
          end

          context 'with validation disabled' do
            let(:validate_approvals_required) { false }

            let(:action) do
              {
                type: 'require_approval',
                user_approvers: [user.username],
                approvals_required: 42
              }
            end

            it_behaves_like 'passes validation'
          end

          context 'with user_approvers' do
            let(:action) do
              {
                type: 'require_approval',
                user_approvers: [user.username]
              }
            end

            context 'with exceeding approvals_required' do
              before do
                action[:approvals_required] = 2
              end

              it_behaves_like 'fails validation'
            end

            context 'with sufficient approvals_required' do
              before do
                action[:approvals_required] = 1
              end

              it_behaves_like 'passes validation'
            end
          end

          context 'with group_approvers' do
            let_it_be(:other_user) { create(:user) }
            let(:group) { create(:group) }
            let(:action) do
              {
                type: 'require_approval',
                group_approvers: [group.name]
              }
            end

            before do
              group.add_developer(other_user)
            end

            context 'with exceeding approvals_required' do
              before do
                action[:approvals_required] = 2
              end

              it_behaves_like 'fails validation'
            end

            context 'with sufficient approvals_required' do
              before do
                action[:approvals_required] = 1
              end

              it_behaves_like 'passes validation'
            end

            context 'with sufficient approvals_required through membership inheritance' do
              let(:subgroup) { create(:group, parent: group) }

              let(:action) do
                {
                  type: 'require_approval',
                  group_approvers: [subgroup.name],
                  approvals_required: 1
                }
              end

              it_behaves_like 'passes validation'
            end
          end

          context 'with role_approvers' do
            let(:action) do
              {
                type: 'require_approval',
                role_approvers: %w[developer]
              }
            end

            context 'with exceeding approvals_required' do
              before do
                skip if container.is_a?(Group)

                action[:approvals_required] = 2
              end

              it_behaves_like 'fails validation'
            end

            context 'with sufficient approvals_required' do
              before do
                action[:approvals_required] = 1
              end

              it_behaves_like 'passes validation'
            end
          end

          context 'with compound approvals' do
            let(:group) { create(:group) }
            let(:other_user) { create(:user) }
            let(:action) do
              {
                type: 'require_approval',
                group_approvers: [group.name],
                user_approvers: [other_user.username]
              }
            end

            before do
              group.add_developer(user)
              container.add_developer(other_user)
            end

            context 'with exceeding approvals_required' do
              before do
                action[:approvals_required] = 3
              end

              it_behaves_like 'fails validation'
            end

            context 'with sufficient approvals_required' do
              before do
                action[:approvals_required] = 2
              end

              it_behaves_like 'passes validation'
            end
          end
        end
      end
    end

    shared_examples 'checks if branches exist for the provided branch_type' do
      let(:rule) do
        {
          branch_type: branch_type
        }
      end

      with_them do
        it { expect(result[:status]).to eq(status) }

        it 'returns a corresponding error message for error case' do
          if status == :error
            expect(result[:details]).to eq(["Branch types don't match any existing branches."])
          else
            expect(result[:details]).to be_nil
          end
        end

        it_behaves_like 'checks only if policy is enabled'
      end
    end

    shared_examples 'checks if timezone is valid' do
      context 'when timezone is not provided' do
        it { expect(result[:status]).to eq(:success) }
      end

      context 'when timezone is provided' do
        let(:rule) do
          {
            branches: ['master'],
            cadence: '0 0 * * *',
            timezone: timezone
          }
        end

        context 'when timezone is valid' do
          let(:timezone) { 'Europe/Amsterdam' }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when timezone valid ActiveSupport::TimeZone, but not TZInfo::Timezone' do
          let(:timezone) { 'Pacific Time (US & Canada)' }

          it_behaves_like 'sets validation errors', field: :timezone, message: 'Timezone is invalid'

          it { expect(result[:status]).to eq(:error) }
          it { expect(result[:details]).to match_array(['Timezone is invalid']) }
        end

        context 'when timezone is empty string' do
          let(:timezone) { '' }

          it_behaves_like 'sets validation errors', field: :timezone, message: 'Timezone is invalid'

          it { expect(result[:status]).to eq(:error) }
          it { expect(result[:details]).to match_array(['Timezone is invalid']) }
        end

        context 'when timezone is invalid' do
          let(:timezone) { 'invalid' }

          it_behaves_like 'sets validation errors', field: :timezone, message: 'Timezone is invalid'

          it { expect(result[:status]).to eq(:error) }
          it { expect(result[:details]).to match_array(['Timezone is invalid']) }
        end
      end
    end

    shared_examples 'checks if cadence is valid' do
      context 'when cadence is provided' do
        let(:rule) do
          {
            branches: ['master'],
            cadence: cadence,
            timezone: 'Europe/Amsterdam'
          }
        end

        context 'when cadence is valid' do
          let(:cadence) { '0 0 * * *' }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when cadence is invalid' do
          let(:cadence) { '* * * * *' }

          it_behaves_like 'sets validation errors', field: :cadence, message: 'Cadence is invalid'

          it { expect(result[:status]).to eq(:error) }
          it { expect(result[:details]).to match_array(['Cadence is invalid']) }
        end
      end
    end

    shared_examples 'checks if vulnerability_age is valid' do
      let(:new_states) { %w[new_needs_triage newly_detected] }
      let(:new_and_previously_existing_states) { %w[detected new_needs_triage] }
      let(:previously_existing_states) { %w[detected confirmed resolved dismissed] }

      Security::ScanResultPolicy::SCAN_RESULT_POLICY_TYPES.each do |type|
        context "when policy_type is #{type}" do
          let(:policy_type) { type }

          context 'when vulnerability_age is not provided' do
            it { expect(result[:status]).to eq(:success) }
          end

          context 'when vulnerability_age is provided' do
            let(:rule) do
              {
                branches: ['master'],
                vulnerability_states: vulnerability_states,
                vulnerability_age: {
                  value: 1,
                  interval: 'day',
                  operator: 'less_than'
                }
              }
            end

            where(:vulnerability_states, :status) do
              nil                                       | :error
              []                                        | :error
              ref(:new_states)                          | :error
              ref(:new_and_previously_existing_states)  | :success
              ref(:previously_existing_states)          | :success
            end

            with_them do
              it { expect(result[:status]).to eq(status) }

              it 'returns a corresponding error message for error case' do
                if status == :error
                  expect(result[:details]).to contain_exactly(/Vulnerability age requires previously existing/)
                else
                  expect(result[:details]).to be_nil
                end
              end

              it_behaves_like 'sets validation errors', field: :vulnerability_age, message: /Vulnerability age requires previously existing/ do
                before do
                  skip if status != :error
                end
              end
            end
          end
        end
      end
    end

    shared_examples 'pipeline execution policy validation' do
      let(:policy_type) { 'pipeline_execution_policy' }
      let(:name) { 'New policy' }
      let(:policy) do
        attributes_for(:pipeline_execution_policy).merge(type: policy_type, name: name, enabled: enabled)
      end

      it { expect(result[:status]).to eq(:success) }
    end

    context 'when project or namespace is not provided' do
      let_it_be(:container) { nil }

      it_behaves_like 'checks policy type'
      it_behaves_like 'checks policy name'
      it_behaves_like 'checks if branches are provided in rule'
      it_behaves_like 'checks if timezone is valid'
      it_behaves_like 'checks if vulnerability_age is valid'
      it_behaves_like 'checks if cadence is valid'
    end

    context 'when project is provided' do
      let_it_be(:default_branch) { 'master' }
      let_it_be(:protected_branch) { 'protected' }
      let_it_be(:unprotected_branch) { 'feature' }

      def setup_repository(project, branches)
        sha = project.repository.create_file(
          project.creator,
          "README.md",
          "",
          message: "initial commit",
          branch_name: branches.first)
        branches.each do |branch|
          project.repository.add_branch(project.creator, branch, sha)
        end
      end

      context 'when repository is empty' do
        let_it_be(:container) { create(:project, :empty_repo) }

        it_behaves_like 'checks policy type'
        it_behaves_like 'checks policy name'
        it_behaves_like 'checks if branches exist for the provided branch_type' do
          where(:policy_type, :branch_type, :status) do
            :scan_execution_policy | 'all' | :error
            :scan_execution_policy | 'protected' | :error
            :scan_execution_policy | 'default' | :error
            :scan_result_policy | 'protected' | :error
            :scan_result_policy | 'default' | :error
            :approval_policy | 'protected' | :error
            :approval_policy | 'default' | :error
          end
        end

        it_behaves_like 'pipeline execution policy validation'
      end

      context 'when project has a default protected branch' do
        let_it_be(:container) { create(:project, :repository) }

        before_all do
          container.protected_branches.create!(name: 'master')
        end

        it_behaves_like 'checks policy type'
        it_behaves_like 'checks policy name'
        it_behaves_like 'checks if branches are provided in rule'
        it_behaves_like 'checks if branches are defined in the project'
        it_behaves_like 'checks if required approvals exceed eligible approvers'
        it_behaves_like 'checks if timezone is valid'
        it_behaves_like 'checks if cadence is valid'
        it_behaves_like 'checks if vulnerability_age is valid'
        it_behaves_like 'checks if branches exist for the provided branch_type' do
          where(:policy_type, :branch_type, :status) do
            :scan_execution_policy | 'all' | :success
            :scan_execution_policy | 'protected' | :success
            :scan_execution_policy | 'default' | :success
            :scan_result_policy | 'protected' | :success
            :scan_result_policy | 'default' | :success
            :approval_policy | 'protected' | :success
            :approval_policy | 'default' | :success
          end
        end

        it_behaves_like 'pipeline execution policy validation'
      end

      context 'when project has a non-default protected branch' do
        let_it_be(:container) { create(:project, :empty_repo) }

        before_all do
          setup_repository(container, [default_branch, protected_branch])
          container.protected_branches.create!(name: protected_branch)
        end

        it_behaves_like 'checks policy type'
        it_behaves_like 'checks policy name'
        it_behaves_like 'checks if branches are provided in rule'
        it_behaves_like 'checks if branches are defined in the project'
        it_behaves_like 'checks if required approvals exceed eligible approvers'
        it_behaves_like 'checks if timezone is valid'
        it_behaves_like 'checks if cadence is valid'
        it_behaves_like 'checks if vulnerability_age is valid'
        it_behaves_like 'checks if branches exist for the provided branch_type' do
          where(:policy_type, :branch_type, :status) do
            :scan_execution_policy | 'all' | :success
            :scan_execution_policy | 'protected' | :success
            :scan_execution_policy | 'default' | :success
            :scan_result_policy | 'protected' | :success
            :scan_result_policy | 'default' | :error
            :approval_policy | 'protected' | :success
            :approval_policy | 'default' | :error
          end
        end

        it_behaves_like 'pipeline execution policy validation'
      end

      context 'when project has only a default unprotected branch' do
        let_it_be(:container) { create(:project, :empty_repo) }

        before_all do
          setup_repository(container, [unprotected_branch])
        end

        it_behaves_like 'checks policy type'
        it_behaves_like 'checks policy name'
        it_behaves_like 'checks if branches exist for the provided branch_type' do
          where(:policy_type, :branch_type, :status) do
            :scan_execution_policy | 'all' | :success
            :scan_execution_policy | 'protected' | :error
            :scan_execution_policy | 'default' | :success
            :scan_result_policy | 'protected' | :error
            :scan_result_policy | 'default' | :error
            :approval_policy | 'protected' | :error
            :approval_policy | 'default' | :error
          end

          context 'with multiple rules' do
            where(:branch_type1, :branch_type2, :status) do
              'protected' | 'default' | :error
              'all' | 'protected' | :error
              'all' | 'default' | :success
            end

            with_them do
              let(:rules) do
                [{ branch_type: branch_type1 }, { branch_type: branch_type2 }]
              end

              it { expect(result[:status]).to eq(status) }
            end
          end
        end

        it_behaves_like 'pipeline execution policy validation'
      end
    end

    context 'when namespace is provided' do
      let_it_be(:container) { create(:group) }

      it_behaves_like 'checks policy type'
      it_behaves_like 'checks policy name'
      it_behaves_like 'checks if branches are provided in rule'
      it_behaves_like 'checks if required approvals exceed eligible approvers'
      it_behaves_like 'checks if timezone is valid'
      it_behaves_like 'checks if cadence is valid'
      it_behaves_like 'checks if vulnerability_age is valid'

      it_behaves_like 'pipeline execution policy validation'

      context 'when policy_scope is present' do
        let_it_be(:framework_1) { create(:compliance_framework, namespace: container.root_ancestor) }
        let_it_be(:framework_2) { create(:compliance_framework, namespace: container.root_ancestor, name: 'SOX') }
        let_it_be(:invaild_framework) { create(:compliance_framework) }

        let(:policy) do
          {
            type: policy_type,
            name: name,
            policy_scope: policy_scope,
            enabled: enabled,
            rules: rules
          }
        end

        let(:policy_scope) do
          {
            compliance_frameworks: [
              { id: framework_1.id },
              { id: framework_2.id }
            ]
          }
        end

        context 'when policy_scope is empty' do
          let(:policy_scope) { {} }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when compliance_frameworks is empty' do
          let(:policy_scope) { { compliance_frameworks: [] } }

          it { expect(result[:status]).to eq(:success) }
        end

        context 'when compliance framework ids are valid' do
          it { expect(result[:status]).to eq(:success) }
        end

        context 'when compliance frameworks contain invalid ids' do
          let(:policy_scope) do
            {
              compliance_frameworks: [
                { id: framework_1.id },
                { id: invaild_framework.id }
              ]
            }
          end

          it_behaves_like 'sets validation errors', field: :compliance_frameworks, message: 'Invalid Compliance Framework ID(s)'
        end
      end
    end
  end
end
