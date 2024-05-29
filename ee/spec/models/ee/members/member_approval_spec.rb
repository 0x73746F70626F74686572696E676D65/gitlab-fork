# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::MemberApproval, feature_category: :groups_and_projects do
  describe 'validations' do
    context 'when uniqness is enforced' do
      let!(:user) { create(:user) }
      let!(:group) { create(:group) }
      let!(:member_approval) { create(:member_approval, user: user, member_namespace: group) }

      context 'with same user, namespace, access level, and pending status' do
        let(:message) { 'A pending approval for the same user, namespace, and access level already exists.' }

        it 'disallows on create' do
          duplicate_approval = build(:member_approval, user: user, member_namespace: group)

          expect(duplicate_approval).not_to be_valid
          expect(duplicate_approval.errors[:base]).to include(message)
        end

        it 'disallows on update' do
          duplicate_approval = create(:member_approval, user: user, member_namespace: group, status: :approved)
          expect(duplicate_approval).to be_valid

          duplicate_approval.status = ::Members::MemberApproval.statuses[:pending]
          expect(duplicate_approval).not_to be_valid
          expect(duplicate_approval.errors[:base]).to include(message)
        end

        context 'with member_role_id' do
          let(:billable_member_role) do
            create(:member_role, :guest, namespace: nil, read_vulnerability: true)
          end

          let(:another_billable_member_role) do
            create(:member_role, :guest, namespace: nil, read_vulnerability: true)
          end

          let!(:member_approval) do
            create(:member_approval, user: user, member_namespace: group, member_role_id: billable_member_role.id)
          end

          it 'disallows with same member_role_id' do
            duplicate_approval = build(:member_approval,
              user: user, member_namespace: group, member_role_id: billable_member_role.id)

            expect(duplicate_approval).not_to be_valid
            expect(duplicate_approval.errors[:base]).to include(message)
          end

          it 'allows with different member_role_id' do
            duplicate_approval = build(:member_approval,
              user: user, member_namespace: group, member_role_id: another_billable_member_role.id)

            expect(duplicate_approval).to be_valid
            expect(duplicate_approval.errors[:base]).to be_empty
          end
        end
      end

      it 'allows duplicate member approvals with different statuses' do
        member_approval.update!(status: ::Members::MemberApproval.statuses[:approved])

        pending_approval = build(:member_approval, user: user, member_namespace: group)

        expect(pending_approval).to be_valid
      end

      it 'allows duplicate member approvals with different access levels' do
        different_approval = build(:member_approval,
          user: user,
          member_namespace: group,
          new_access_level: ::Gitlab::Access::MAINTAINER)

        expect(different_approval).to be_valid
      end
    end
  end

  describe '#pending_member_approvals_with_max_new_access_level' do
    let_it_be(:project_member_pending_dev) { create(:member_approval, :for_project_member) }
    let_it_be(:project_member_pending_maintainer) do
      create(:member_approval, user: project_member_pending_dev.user, new_access_level: Gitlab::Access::MAINTAINER)
    end

    let_it_be(:group_member_pending_dev) { create(:member_approval, :for_group_member) }
    let_it_be(:group_member_pending_owner) do
      create(:member_approval, :for_group_member, user: group_member_pending_dev.user,
        new_access_level: Gitlab::Access::OWNER)
    end

    let_it_be(:denied_approval_dev) { create(:member_approval, :for_group_member, status: :denied) }

    it 'returns records corresponding to pending users with max new_access_level' do
      expect(described_class.pending_member_approvals_with_max_new_access_level).to contain_exactly(
        project_member_pending_maintainer, group_member_pending_owner
      )
    end
  end
end
