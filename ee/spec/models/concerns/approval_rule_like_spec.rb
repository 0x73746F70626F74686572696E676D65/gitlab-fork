# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRuleLike, feature_category: :source_code_management do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:group1) { create(:group) }
  let(:group2) { create(:group) }

  let(:merge_request) { create(:merge_request) }

  let(:subject_traits) { [] }

  shared_examples 'approval rule like' do
    let(:group1_user) { create(:user) }
    let(:group2_user) { create(:user) }

    before do
      subject.users << user1
      subject.users << user2
      subject.groups << group1
      subject.groups << group2

      group1.add_guest(group1_user)
      group2.add_guest(group2_user)
    end

    describe '#approvers_include_user?' do
      let(:rule) { subject.class.find(subject.id) }

      it 'returns true for a contained user' do
        expect(rule.approvers_include_user?(user1)).to be_truthy
      end

      it 'returns true for a group user' do
        expect(rule.approvers_include_user?(group1_user)).to be_truthy
      end

      it 'returns false for a missing user' do
        expect(rule.approvers_include_user?(user3)).to be_falsey
      end

      context 'when the user relations are already loaded' do
        it 'returns true for a contained user' do
          rule.users.to_a

          expect(rule.approvers_include_user?(user1)).to be_truthy
        end

        it 'returns true for a group user' do
          rule.group_members.to_a

          expect(rule.approvers_include_user?(group1_user)).to be_truthy
        end

        it 'returns false for a missing user' do
          rule.users.to_a

          expect(rule.approvers_include_user?(user3)).to be_falsey
        end
      end
    end

    describe '#approvers' do
      shared_examples 'approvers contains the right users' do
        it 'contains users as direct members and group members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user)
        end

        context 'when some users are inactive' do
          before do
            user2.block!
            group2_user.block!
          end

          it 'returns users that are only active' do
            rule = subject.class.find(subject.id)

            expect(rule.approvers).to contain_exactly(user1, group1_user)
          end
        end
      end

      it_behaves_like 'approvers contains the right users'

      context 'when the user relations are already loaded' do
        before do
          subject.users.to_a
          subject.group_users.to_a
        end

        it 'does not perform any new queries when all users are loaded already' do
          # single query is triggered for license check
          expect { subject.approvers }.not_to exceed_query_limit(1)
        end

        it_behaves_like 'approvers contains the right users'
      end

      context 'when user is both a direct member and a group member' do
        before do
          group1.add_guest(user1)
          group2.add_guest(user2)
        end

        it 'contains only unique users' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user)
        end
      end

      context 'when scan_result_policy_read has role_approvers' do
        let_it_be(:user4) { create(:user) }
        let_it_be(:scan_result_policy_read) do
          create(:scan_result_policy_read, role_approvers: [Gitlab::Access::MAINTAINER])
        end

        before do
          subject.update!(scan_result_policy_read: scan_result_policy_read)
          group1.add_maintainer(user4)
        end

        it 'contains users as direct members and group members and role members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user, user4)
        end
      end
    end

    describe '#from_scan_result_policy?' do
      context 'when report_type is scan_finding' do
        let(:subject_traits) { %i[scan_finding] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to eq(true)
        end
      end

      context 'when report_type is license_scanning' do
        let(:subject_traits) { %i[license_scanning] }

        context 'when scan_result_policy_read is defined' do
          let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read) }

          before do
            subject.update!(scan_result_policy_read: scan_result_policy_read)
          end

          it 'returns true' do
            expect(subject.from_scan_result_policy?).to eq(true)
          end
        end

        context 'when scan_result_policy_read is not defined' do
          it 'returns false' do
            expect(subject.from_scan_result_policy?).to eq(false)
          end
        end
      end

      context 'when report_type is any_merge_request' do
        let(:subject_traits) { %i[any_merge_request] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to eq(true)
        end
      end

      context 'when report_type is nil' do
        before do
          subject.update!(report_type: nil)
        end

        it 'returns false' do
          expect(subject.from_scan_result_policy?).to eq(false)
        end
      end
    end

    describe '#policy_name' do
      it 'trims trailing digit coming from multiple rules belonging to the same policy' do
        subject.update!(name: 'Policy 1')
        expect(subject.policy_name).to eq('Policy')
      end
    end

    describe 'validation' do
      context 'when value is too big' do
        it 'is invalid' do
          subject.approvals_required = described_class::APPROVALS_REQUIRED_MAX + 1

          expect(subject).to be_invalid
          expect(subject.errors.key?(:approvals_required)).to eq(true)
        end
      end

      context 'when value is within limit' do
        it 'is valid' do
          subject.approvals_required = described_class::APPROVALS_REQUIRED_MAX

          expect(subject).to be_valid
        end
      end

      context 'with rule_type set to report_approver' do
        before do
          subject.rule_type = :report_approver
        end

        it 'is invalid' do
          subject.report_type = nil
          expect(subject).not_to be_valid
        end
      end

      context 'when importing' do
        before do
          subject.importing = true
        end

        context 'when orchestration_policy_idx is not nil' do
          it 'is invalid' do
            subject.orchestration_policy_idx = 2

            expect(subject).to be_invalid
            expect(subject.errors.key?(:orchestration_policy_idx)).to eq(true)
          end
        end

        context 'when orchestration_policy_idx is nil' do
          it 'is valid' do
            subject.orchestration_policy_idx = nil

            expect(subject).to be_valid
          end
        end

        context 'when report type is nil' do
          it 'is valid' do
            subject.report_type = nil

            expect(subject).to be_valid
          end
        end

        context 'when report type is scan_finding' do
          it 'is invalid' do
            subject.report_type = :scan_finding

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is license_scanning' do
          it 'is invalid' do
            subject.report_type = :license_scanning

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is code_coverage' do
          it 'is valid' do
            subject.report_type = :code_coverage
            subject.name = 'Coverage-Check'

            expect(subject).to be_valid
          end
        end
      end
    end
  end

  context 'MergeRequest' do
    subject { create(:approval_merge_request_rule, *subject_traits, merge_request: merge_request) }

    it_behaves_like 'approval rule like'

    describe '#overridden?' do
      it 'returns false' do
        expect(subject.overridden?).to be_falsy
      end

      context 'when rule has source rule' do
        let(:source_rule) do
          create(
            :approval_project_rule,
            project: merge_request.target_project,
            name: 'Source Rule',
            approvals_required: 2,
            users: [user1, user2],
            groups: [group1, group2]
          )
        end

        before do
          subject.update!(approval_project_rule: source_rule)
        end

        context 'and any attributes differ from source rule' do
          shared_examples_for 'overridden rule' do
            it 'returns true' do
              expect(subject.overridden?).to be_truthy
            end
          end

          context 'name' do
            before do
              subject.update!(name: 'Overridden Rule')
            end

            it_behaves_like 'overridden rule'
          end

          context 'approvals_required' do
            before do
              subject.update!(approvals_required: 1)
            end

            it_behaves_like 'overridden rule'
          end

          context 'users' do
            before do
              subject.update!(users: [user1])
            end

            it_behaves_like 'overridden rule'
          end

          context 'groups' do
            before do
              subject.update!(groups: [group1])
            end

            it_behaves_like 'overridden rule'
          end
        end

        context 'and no changes made to attributes' do
          before do
            subject.update!(
              name: source_rule.name,
              approvals_required: source_rule.approvals_required,
              users: source_rule.users,
              groups: source_rule.groups
            )
          end

          it 'returns false' do
            expect(subject.overridden?).to be_falsy
          end
        end
      end
    end
  end

  context 'Project' do
    subject { create(:approval_project_rule, *subject_traits) }

    it_behaves_like 'approval rule like'

    describe '#overridden?' do
      it 'returns false' do
        expect(subject.overridden?).to be_falsy
      end
    end
  end

  describe '.group_users' do
    subject { create(:approval_project_rule) }

    it 'returns distinct users' do
      group1.add_guest(user1)
      group2.add_guest(user1)
      subject.groups = [group1, group2]

      expect(subject.group_users).to eq([user1])
    end
  end

  describe '.exportable' do
    let_it_be(:project) { create(:project) }

    let_it_be(:any_approver_rule) { create(:approval_project_rule, :any_approver_rule, project: project) }
    let_it_be(:license_scanning_rule) { create(:approval_project_rule, :license_scanning, project: project) }
    let_it_be(:code_coverage) { create(:approval_project_rule, :code_coverage, project: project) }
    let_it_be(:scan_finding) { create(:approval_project_rule, :scan_finding, project: project) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    subject { project.approval_rules.exportable }

    it 'does not include rules created from scan result policies' do
      is_expected.to match_array([any_approver_rule, code_coverage])
    end
  end
end
